//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import FirebaseAnalytics
import ApplicationKey
import CoreData
import DataController
import Foundation
import HealthKit
import SwiftUI
import WidgetKit

class HeadacheManager: ObservableObject {
  
  enum HeadacheError: Error, CustomStringConvertible {
    case testing
    case missing
    
    var description: String {
      switch self {
      case .testing:
        return "This operation is not allowed in test mode."
      case .missing:
        return "The required data was missing."
      }
    }
  }
  
  // MARK: Public properties
  
  /// The manager's weather manager.
  let weatherManager = WeatherManager()
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  let healthKitManager = HealthKitManager()
  
  /// The headache predictor.
  let predictor = Predictor()
  
  // MARK: Private properties
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
  
  /// Whether or not the manager is in test mode. If in test mode, it will not
  /// write to or delete from the health kit store.
  private let testing: Bool
  
  /// The queue to train on.
  private var trainingQueue = DispatchQueue(label: ApplicationKey(from: "trainingQueue"))
  
  // MARK: Initializers
  
  /// Initializes a headache manager.
  ///
  /// - Parameter testing: Set to true for previews.
  init(testing: Bool = false) {
    self.testing = testing
  }
  
}

// MARK: - Current headache methods

extension HeadacheManager {
  
  /// Changes the manager's severity and either creates a new headache, or adds the new
  /// severity to the current headache.
  ///
  /// - Parameter severity: The headache's current severity.
  func changeSeverity(to severity: HKCategoryValueSeverity) async throws {
    logDebug("Change severity to \(severity.title).")
    
    // The date interval of the severity to save to health kit
    let severityInterval: SeverityInterval? = try await currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        return headache.addSeverity(severity, startTime: Date())
      }
      
      logDebug("Creating new headache.")
      _ = Headache(context: context, initialSeverity: severity, startTime: Date())
      return nil
    }
    
    // If there wasn't an error, then update the widget data and continue
    SharedUserDefaults.standard.setCurrentSeverity(severity)
    
    // Write the data to health kit and set our check-in alert
    try await healthKitManager.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
    
    // Update the CoreML training data
    try await createPredict()
  }
  
  /// Resolves the headache.
  func resolve() async throws {
    logDebug("Resolve headache.")
    
    // Get the current headache
    let severityInterval: SeverityInterval? = try await currentHeadache { headache, context in
      // Resolve the headache
      if let headache = headache {
        return headache.resolve(endTime: Date())
      }
      else {
        logWarning("No current headache to resolve.")
      }
      return nil
    }
    
    // If there wasn't an error, then update the widget data and continue
    SharedUserDefaults.standard.setCurrentSeverity(nil)
    
    // Write the data to health kit
    try await healthKitManager.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
    
    // Update the CoreML models
    try await createPredict()
  }
  
  /// Deletes the current headache.
  func reset() async throws {
    logDebug("Reset headache.")
    
    // The start and end times to delete from health kit
    var startTime: Date?
    var endTime: Date?
    
    // Get the current headache
    try await currentHeadache { headache, context in
      logDebug("Resetting headache.")
      
      // If we have a current headache, then delete it
      if let headache = headache {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
      }
    }
    
    // If there wasn't an error, then update the widget data and continue
    SharedUserDefaults.standard.setCurrentSeverity(nil)
    
    // If there wasn't an error, then we should check and delete it from health kit
    if let startTime = startTime, let endTime = endTime {
      logDebug("Successfully reset headache. Deleting severity samples.")
      try await healthKitManager.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime))
    }
    else {
      logDebug("Successfully reset headache, but not deleting severity samples.")
    }
  }
  
}

// MARK: - Object management methods

extension HeadacheManager {
  
  /// Adds a new severity to the headache with the given identifier.
  ///
  /// - Parameter identifier: The headache's identifier.
  func addSeverityToHeadache(identifier: UUID) async throws {
    logDebug("Add severity.")
    
    // The date interval of the severity to save to health kit
    
    
    // Get the headache
    let severityInterval: SeverityInterval? = try await headacheWithIdentifier(identifier: identifier) { headache, context in
      if let headache = headache {
        return headache.addSeverity(.notPresent, duration: 3600.0)
      }
      return nil
    }
    
    try await healthKitManager.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
  }
  
  /// Deletes the headache with the given identifier and it's associated health kit data.
  ///
  /// - Parameter identifier: The headache's identifier.
  func deleteHeadache(identifier: UUID?) async throws {
    logDebug("Delete headache.")
    guard let identifier = identifier else {
      return
    }
    
    // The start and end times to delete from health kit
    var startTime: Date?
    var endTime: Date?
    
    try await headacheWithIdentifier(identifier: identifier) { headache, context in
      logDebug("Deleting headache.")
      
      // Get the headache
      if let headache = headache {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
        
        // If this headache was the current headache, then cancel any pending check-in notifications
        // and reset the current severity.
        if !headache.resolved {
          SharedUserDefaults.standard.setCurrentSeverity(nil)
        }
      }
    }
    
    // If there wasn't an error, then we should check and delete it from health kit
    if let startTime = startTime, let endTime = endTime {
      logDebug("Successfully reset headache. Deleting severity samples.")
      try await healthKitManager.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime))
    }
    else {
      logDebug("Successfully reset headache, but not deleting severity samples.")
    }
  }
  
  /// Deletes the severity with the given identifier.
  ///
  /// - Parameter identifier: The severity's identifier.
  func deleteSeverity(identifier: UUID?) async throws {
    logDebug("Delete severity.")
    guard let identifier = identifier else {
      return
    }
    
    var originalHeadacheInterval: DateInterval?
    var newSeveritySamples = [SeverityInterval]()
    
    try await severityWithIdentifier(identifier: identifier) { severity, context in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        headache?.removeFromSeverities(severity)
        context.delete(severity)
        headache?.reorganize()
        
        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    }
    
    // Check to see if we need to delete and re-add samples
    if let originalHeadacheInterval = originalHeadacheInterval {
      try await healthKitManager.deleteSeveritySamples(in: originalHeadacheInterval)
      try await healthKitManager.saveSeveritySamples(intervals: newSeveritySamples)
    }
  }
  
  /// Updates the severity with the given identifier.
  ///
  /// - Parameter identifier: The severity's identifier.
  func updateSeverity(identifier: UUID, value: HKCategoryValueSeverity, startTime: Date, endTime: Date) async throws {
    logDebug("Update severity.")
    
    var originalHeadacheInterval: DateInterval?
    var newSeveritySamples = [SeverityInterval]()
    
    try await severityWithIdentifier(identifier: identifier) { severity, context in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        severity.severity = value
        severity.startTime = startTime
        severity.endTime = endTime
        headache?.reorganize()
        
        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    }
    
    // Check to see if we need to delete and re-add samples
    if let originalHeadacheInterval = originalHeadacheInterval {
      try await healthKitManager.deleteSeveritySamples(in: originalHeadacheInterval)
      try await healthKitManager.saveSeveritySamples(intervals: newSeveritySamples)
    }
  }
  
}

// MARK: - Getting headaches and severities

extension HeadacheManager {
  
  /// Gets the current headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the current headache to update it.
  ///   Errors thrown in this block will be received in completion.
  private func currentHeadache<T>(update: @escaping (Headache?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "ANY severities.endTime = nil")
      return try update(try context.fetch(request).first, context)
    }
  }
  
  /// Gets the headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the headache to update it. Errors
  ///   thrown in this block will be received in completion.
  private func headacheWithIdentifier<T>(identifier: UUID, update: @escaping (Headache?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest(withIdentifier: identifier)
      return try update((try context.fetch(request)).first, context)
    }
  }
  
  /// Gets the severity and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the severity to update it. Errors
  ///   thrown in this block will be received in completion.
  private func severityWithIdentifier<T>(identifier: UUID, update: @escaping (Severity?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Severity.fetchRequest(withIdentifier: identifier)
      return try update((try context.fetch(request)).first, context)
    }
  }
  
  /// Gets the sorted training data and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameters:
  ///   - predicate: The (optional) predicate to apply.
  ///   - fetchLimit: The limit of fetch results to return.
  ///   - ascending: Whether the returned list is ascending date order.
  ///   - update: Called with the training data to update it. Errors thrown in
  ///     this block will be received in completion.
  private func trainingData<T>(predicate: NSPredicate? = nil, fetchLimit: Int = 0, ascending: Bool = true, update: @escaping ([TrainingData], NSManagedObjectContext) throws -> T) async throws -> T {
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
      request.predicate = predicate
      request.fetchLimit = fetchLimit
      return try update(try context.fetch(request), context)
    }
  }
  
  /// Gets the date of the last training data sample.
  ///
  /// - Returns: A date.
  func lastTrainingDataDate() async throws -> Date? {
    return try await trainingData(fetchLimit: 1, ascending: false) { trainingData, _ in
      return trainingData.first?.timestamp
    }
  }
  
  func hasCurrentHeadache() async throws -> Bool {
    return try await currentHeadache { headache, _ in
      return headache != nil
    }
  }
  
  func currentHeadacheIdentifier() async throws -> UUID? {
    return try await currentHeadache { headache, _ in
      return headache?.identifier
    }
  }
  
  func currentSeverityIdentifier() async throws -> UUID? {
    return try await currentHeadache { headache, _ in
      return headache?.severitiesArray.last?.identifier
    }
  }
  
}

// MARK: Prediction

extension HeadacheManager {
  
  /// Resets all prediction and learning data.
  func resetPrediction() {
    predictor.reset()
  }
  
  /// Whether or not the application needs more training data.
  ///
  /// - Returns: A boolean indicating if the app should ask for more training data.
  func needsTrainingData() async throws -> Bool {
    guard let timestamp = try await lastTrainingDataDate() else {
      return true
    }
    
    return Date().timeIntervalSince(timestamp) > 3600.0 // Every 1 hour
  }
  
  /// Whether or not the device contains training data that's newer than
  /// the latest compiled models.
  ///
  /// - Returns: A boolean indicating if the app needs to train its models.
  func needsTraining() async throws -> Bool {
    guard let lastTrainingDate = predictor.modelUpdatedAt, let timestamp = try await lastTrainingDataDate() else {
      return false
    }
    
    return timestamp.timeIntervalSince(lastTrainingDate) > 0.0
  }
  
  /// Cancels the current classification input reading.
  func cancelClassificationInput() {
    weatherManager.cancel()
  }
  
  func predictorInput(inWidget: Bool = false) async throws -> Predictor.Input {
    let weather = try await weatherManager.weather()
    let now = Date()
    let interval = DateInterval(start: now.addingTimeInterval(-86400.0), end: now)
    let healthKitData = healthKitManager.readHealthKitData(in: interval, inWidget: inWidget)
    return Predictor.Input(weather: weather, healthKitData: healthKitData, date: now)
  }
  
  /// Gets classifier input appropriate for prediction, saves it as traininig
  /// data, runs a prediction, and evaluates the prediction.
  ///
  /// - Parameters:
  ///   - create: Set to true if the headache manager should create training
  ///     data with the prediction.
  ///   - predict: Runs a prediction before returning the input if true.
  ///   - inWidget: Whether this method is being called by a widget.
  func createPredict(create: Bool = true, predict: Bool = true, inWidget: Bool = false) async throws {
    let input = try await predictorInput(inWidget: inWidget)
    
    if create {
      let identifier = try await currentSeverityIdentifier()
      try await createTrainingData(from: input, severityIdentifier: identifier)
    }
    
    if predict {
      let prediction = try await predictor.predict(input, reloadWidget: !inWidget)
      try await evaluatePrediction(prediction)
    }
  }
  
  /// Create new training data and sets its `severity` relationship to the severity
  /// with the given identifier. If no identifier is present, then the training data is
  /// still created but orphaned (a not-present severity).
  ///
  /// - Parameters:
  ///   - input: The input data to create the training data from.
  ///   - severityIdentifier: The identifier of the training data's parent severity, if any.
  func createTrainingData(from input: Predictor.Input, severityIdentifier: UUID? = nil) async throws {
    guard !testing else { throw HeadacheError.testing }
    
    logInfo("Creating training data...")
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Create the training data
      let trainingData = TrainingData(context: context, input: input)
      logDebug("Created training data.")
      
      if let severityIdentifier = severityIdentifier {
        let request = Severity.fetchRequest(withIdentifier: severityIdentifier)
        if let severity = ((try? context.fetch(request)) ?? []).first {
          severity.addToTrainingData(trainingData)
        }
        else {
          logWarning("Unable to add training data to severity with identifier: \(severityIdentifier.uuidString)")
        }
      }
    }
  }
  
  /// Upgrades the app's training data.
  func upgradeTrainingData() async throws {
    logInfo("Upgrading training data.")
    try await trainingData(predicate: NSPredicate(format: "(version != %@) OR (version == %@)", Constants.trainingDataVersion as NSString, NSNull())) { [weak self] trainingData, _ in
      logInfo("Performing upgrade on \(trainingData.count) data.")
      // Perform the upgrade
      for trainingDatum in trainingData {
        guard let timestamp = trainingDatum.timestamp else {
          continue
        }

        let interval = DateInterval(start: timestamp.addingTimeInterval(-86400.0), end: timestamp)
        let data = self?.healthKitManager.readHealthKitData(in: interval)
        trainingDatum.updateWithHealthKitData(data)
      }
      logDebug("Finished upgrading data.")
    }
  }
  
  /// Trains the classifiers.
  ///
  /// - Parameter completion: Called when training is complete.
  func trainClassifiers() async throws {
    guard !testing else { throw HeadacheError.testing }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      Task {
        do {
          try await trainingData(predicate: NSPredicate(format: "version == %@", Constants.trainingDataVersion as NSString)) { [weak self] trainingData, _ in
            guard let self = self else {
              continuation.resume()
              return
            }
            
            // Get the training input
            let input = try Predictor.TrainingInput(trainingData: trainingData)
            
            logDebug("Training classifiers with \(trainingData.count) data...")
            Task {
              do {
                try await self.predictor.train(input)
                continuation.resume()
              }
              catch {
                logError("Error training classifiers: \(error)")
                continuation.resume(throwing: error)
              }
            }
          }
        }
        catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
  
  /// Evaluates the prediction and saves it to core data.
  ///
  /// - Parameter prediction: The prediction.
  private func evaluatePrediction(_ prediction: Predictor.Prediction) async throws {
    let hasCurrent = try await hasCurrentHeadache()
    let severity = try await currentHeadache { headache, _ in
      return headache?.severity ?? .notPresent
    }
    
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let evaluation = Evaluation(context: context)
      evaluation.timestamp = Date()
      evaluation.outlook = hasCurrent && prediction.outlookClassifierOutput.prediction == .headache
      evaluation.severity = severity == prediction.severityClassifierOutput.prediction
    }
  }
  
  /// Calculates the current model evaluation metrics for the outlook
  /// and severity predictions.
  ///
  /// - Returns: A pair of evaluation metrics and a count (outlook, severity, count).
  func evaluation() async throws -> (Double, Double, Int) {
    return try await DataController.shared.performInBackground { context in
      let request = Evaluation.fetchRequest()
      let evaluations = try context.fetch(request)
      
      guard evaluations.count > 0 else {
        return (0.0, 0.0, 0)
      }
      
      var outlookSuccess = 0
      var severitySuccess = 0
      for evaluation in evaluations {
        outlookSuccess += evaluation.outlook ? 1 : 0
        severitySuccess += evaluation.severity ? 1 : 0
      }
      
      let evaluationCount = Double(evaluations.count)
      return (Double(outlookSuccess) / evaluationCount, Double(severitySuccess) / evaluationCount, evaluations.count)
    }
  }
  
  /// Deletes all of the stored evaluations.
  func resetEvaluation() async throws {
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Evaluation.fetchRequest()
      let evaluations = try context.fetch(request)
      
      for evaluation in evaluations {
        context.delete(evaluation)
      }
    }
  }
  
}
