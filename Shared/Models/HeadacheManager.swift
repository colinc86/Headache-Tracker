//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import CoreData
import CoreLocation
import DataController
import Foundation
import SwiftUI
import WidgetKit

class HeadacheManager: ObservableObject {
  
  enum HeadacheError: Error, CustomStringConvertible {
    case testing
    case missing
    case headacheDateRange
    
    var description: String {
      switch self {
      case .testing:
        return "This operation is not allowed in test mode."
      case .missing:
        return "The required data was missing."
      case .headacheDateRange:
        return "The headache's onset must be before its end."
      }
    }
  }
  
  enum DeleteDisposition: String, CaseIterable, Identifiable {
    
    typealias ObjectIdentifier = RawValue
    
    var id: ObjectIdentifier {
      rawValue
    }
    
    case always
    case never
    case ask
  }
  
  // MARK: Public properties
  
  /// The manager's weather manager.
  let weatherManager = WeatherManager()
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  let healthKitManager = HealthKitManager()
  
  /// The headache predictor.
  let predictor = Predictor()
  
  /// The manager's location manager.
  let locationManager = LocationManager()
  
  /// Whether a widget is authorized for location updates.
  var authorizedForWidgetUpdates: Bool {
    return locationManager.authorizedForWidgetUpdates
  }
  
  // MARK: Private properties
  
  /// The app's preferences.
  private var preferences = Preferences()
  
  /// The queue to train on.
  private var trainingQueue = DispatchQueue(label: ApplicationKey(from: "trainingQueue"))
  
}

// MARK: - Current headache methods

extension HeadacheManager {
  
  /// Changes the manager's severity and either creates a new headache, or adds the new
  /// severity to the current headache.
  ///
  /// - Parameter severity: The headache's current severity.
  func changeSeverity(to severity: Headache.Severity) async throws {
    logDebug("Change severity to \(severity.title).")
    
    let classification = preferences.headaches.defaultHeadacheClassification
    let type = preferences.headaches.defaultHeadacheType
    
    // The date interval of the severity to save to health kit
    let severityUpdates: Headache.SeverityUpdates = try await currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        return headache.addSeverity(severity, start: Date())
      }
      
      logDebug("Creating new headache.")
      _ = Headache(context: context, severity: severity, classification: classification, type: type, start: Date())
      return .empty
    }
    
    // If there wasn't an error, then update the widget data and continue
    preferences.shared.setCurrentSeverity(severity)
    
    // Write the data to health kit and set our check-in alert
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
    
    // Update the CoreML training data
    try await createPredict(inWidget: false)
  }
  
  /// Resolves the headache.
  func resolve() async throws {
    logDebug("Resolve headache.")
    
    // Get the current headache
    let severityUpdates: Headache.SeverityUpdates = try await currentHeadache { headache, context in
      // Resolve the headache
      if let headache = headache {
        return headache.resolve(end: Date())
      }
      else {
        logWarning("No current headache to resolve.")
      }
      return .empty
    }
    
    // If there wasn't an error, then update the widget data and continue
    preferences.shared.setCurrentSeverity(nil)
    
    // Write the data to health kit
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
    
    // Update the CoreML models
    try await createPredict(inWidget: false)
  }
  
}

// MARK: - Object management methods

extension HeadacheManager {
  
  /// Creates a headache with the given starting severity.
  ///
  /// - Parameters:
  ///   - severity: The headache's starting severity.
  ///   - startTime: The headache's start time.
  ///   - endTime: The headache's end time.
  func createHeadache(severity: Headache.Severity, start: Date, end: Date?) async throws {
    let classification = preferences.headaches.defaultHeadacheClassification
    let type = preferences.headaches.defaultHeadacheType
    
    let severityIdentifier = try await DataController.shared.performInBackground(saveOnComplete: true) { (context) -> UUID? in
      let headache = Headache(context: context, severity: severity, classification: classification, type: type, start: start, end: end)
      return headache.severitiesArray.first?.identifier
    }
    
    // Create the training data
    let input = await predictorInput(atDate: start, inWidget: false)
    try await createTrainingData(from: input, severityIdentifier: severityIdentifier)
  }
  
  /// Adds a new severity to the headache with the given identifier.
  ///
  /// - Parameter identifier: The headache's identifier.
  func addSeverityToHeadache(identifier: UUID) async throws {
    logDebug("Add severity.")
    
    // Get the headache
    let severityUpdates: Headache.SeverityUpdates = try await headacheWithIdentifier(identifier: identifier) { headache, context in
      if let headache = headache {
        return headache.addSeverity(.notPresent, duration: 3600.0)
      }
      return .empty
    }
    
    // Create the training data
    if let identifier = severityUpdates.createdSeverityIdentifier, let startTime = severityUpdates.createdSeverityStartTime {
      let input = await predictorInput(atDate: startTime, inWidget: false)
      try await createTrainingData(from: input, severityIdentifier: identifier)
    }
    
    // Update the health kit samples
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
  }
  
  /// Updates the headache's type.
  ///
  /// - Parameters:
  ///   - type: The new type.
  ///   - classification: The new classification.
  ///   - identifier: The headache's identifier.
  func updateHeadacheType(_ type: Headache.Types, classification: Headache.Classification, identifier: UUID) async throws {
    logDebug("Set type.")
    
    try await headacheWithIdentifier(identifier: identifier) { headache, _ in
      headache?.headacheType = type
      headache?.headacheClassification = classification
    }
  }
  
  /// Updates the headache's notes.
  ///
  /// - Parameters:
  ///   - notes: The headache's notes.
  ///   - identifier: The headache's identifier.
  func updateHeadacheNotes(_ notes: String?, identifier: UUID) async throws {
    logDebug("Set notes.")
    
    // Get the headache and update its notes
    try await headacheWithIdentifier(identifier: identifier) { headache, _ in
      headache?.notes = notes
    }
  }
  
  /// Updates the headache's tags.
  ///
  /// - Parameters:
  ///   - tags: The headache's tags.
  ///   - identifier: The headache's identifier.
  func updateHeadacheTags(_ tags: [String], identifier: UUID) async throws {
    logDebug("Set tags.")
    
    // Get the headache and update its tags
    try await headacheWithIdentifier(identifier: identifier) { headache, context in
      guard let headache = headache else {
        return
      }

      // Remove the headache tags that don't need to be there
      for tag in headache.tagsArray where !tags.contains(tag.value ?? "") {
        // Remove the tag from the headache
        headache.removeFromTags(tag)
        
        // Remove the headache from the tag
        tag.removeFromHeadaches(headache)
        
        // If the tag isn't part of any other headache, delete it
        if tag.headaches?.count == 0 {
          context.delete(tag)
        }
      }
      
      // Add the new tags
      for tag in tags where !headache.tagsArray.contains(where: { $0.value == tag }) {
        // See if the tag already exists
        let request = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "value = %@", tag)
        
        if let existingTag = (try context.fetch(request)).first {
          // It already exists, so add it to the headache
          headache.addToTags(existingTag)
          existingTag.addToHeadaches(headache)
        }
        else {
          // It doesn't already exist, so create a new tag
          let newTag = Tag(context: context)
          newTag.value = tag
          headache.addToTags(newTag)
          newTag.addToHeadaches(headache)
        }
      }
    }
  }
  
  /// Deletes the headache with the given identifier and it's associated health kit data.
  ///
  /// - Parameters:
  ///   - identifier: The headache's identifier.
  ///   - deleteHealthKitData: Whether we should also delete the headache's health kit data.
  func deleteHeadache(identifier: UUID?, deleteHealthKitData: Bool) async throws {
    logDebug("Delete headache.")
    guard let identifier = identifier else {
      return
    }
    
    // The start and end times to delete from health kit
    var startTime: Date?
    var endTime: Date?
    
    try await headacheWithIdentifier(identifier: identifier) { [weak self] headache, context in
      logDebug("Deleting headache.")
      
      // Get the headache
      if let headache = headache {
        // Remove the headache from its tags
        for tag in headache.tagsArray {
          tag.removeFromHeadaches(headache)
          if tag.headaches?.count == 0 {
            context.delete(tag)
          }
        }
        
        // Delete the headache
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
        
        // If this headache was the current headache, then cancel any pending check-in notifications
        // and reset the current severity.
        if !headache.resolved {
          self?.preferences.shared.setCurrentSeverity(nil)
        }
      }
    }
    
    // If there wasn't an error, then we should check and delete it from health kit
    if deleteHealthKitData, let startTime = startTime, let endTime = endTime {
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
    var newSeveritySamples = [Headache.Severity.Interval]()
    
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
  func updateSeverity(identifier: UUID, value: Headache.Severity, startTime: Date, endTime: Date) async throws {
    logDebug("Update severity.")
    
    var originalHeadacheInterval: DateInterval?
    var newSeveritySamples = [Headache.Severity.Interval]()
    
    let modified = try await severityWithIdentifier(identifier: identifier) { (severity, context) -> Bool in
      var modified = false
      
      if let severity = severity {
        modified = severity.startTime != startTime
        
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
      
      return modified
    }
    
    // Update the training data if needed
    if modified {
      let input = await predictorInput(atDate: startTime, inWidget: false)
      try await createTrainingData(from: input, severityIdentifier: identifier, replacingExistingData: true)
    }
    
    // Check to see if we need to delete and re-add samples
    if let originalHeadacheInterval = originalHeadacheInterval {
      try await healthKitManager.deleteSeveritySamples(in: originalHeadacheInterval)
      try await healthKitManager.saveSeveritySamples(intervals: newSeveritySamples)
    }
  }
  
}

// MARK: - Caching

extension HeadacheManager {
  
  /// Updates the application's custom headache types.
  func updateCustomTypes() async throws {
    let types: [Headache.Types] = try await DataController.shared.performInBackground { context in
      let request = Headache.fetchRequest()
      let headaches = try context.fetch(request)
      return headaches.map({ $0.headacheType }).sorted()
    }
    
    let customTypes = types.filter({ !Headache.Types.definedCases.contains($0) })
    let uniqueCustomTypes = customTypes.unique()
    preferences.shared.customTypes = uniqueCustomTypes
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
  private func severityWithIdentifier<T>(identifier: UUID, update: @escaping (SeverityState?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = SeverityState.fetchRequest(withIdentifier: identifier)
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
  
  /// Whether there is a current headache.
  func hasCurrentHeadache() async throws -> Bool {
    return try await currentHeadache { headache, _ in
      return headache != nil
    }
  }
  
  /// The identifier of the current headache.
  func currentHeadacheIdentifier() async throws -> UUID? {
    return try await currentHeadache { headache, _ in
      return headache?.identifier
    }
  }
  
  /// The identifier of the current headache's current severity identifier.
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
    guard let timestamp = try await lastTrainingDataDate() else {
      return false
    }

    guard let lastTrainingDate = predictor.modelUpdatedAt else {
      // No models have been trained yet. Bootstrap the first training run
      // once enough samples have accumulated.
      return try await trainingDataCount() >= Constants.minimumTrainingDataCount
    }

    return timestamp.timeIntervalSince(lastTrainingDate) > 0.0
  }

  /// The number of training data samples.
  ///
  /// - Returns: The count of training data.
  func trainingDataCount() async throws -> Int {
    return try await trainingData { trainingData, _ in
      return trainingData.count
    }
  }
  
  /// Cancels the current classification input reading.
  func cancelClassificationInput() {
    weatherManager.cancel()
    locationManager.cancel()
  }
  
  /// Creates a model input ready for prediction.
  ///
  /// - Parameters:
  ///   - date: The date of the predictor's desired input.
  ///   - inWidget: Whether this method is being called from within a widget.
  /// - Returns: Model input for the specified date.
  func predictorInput(atDate date: Date, inWidget: Bool) async -> ModelInput {
    // Get the location
    var location: CLLocation?
    do {
      location = try await locationManager.location()
    }
    catch {
      logError("Error getting location: \(error)")
    }
    
    // Get the weather
    var weather: Weather?
    if let location = location {
      do {
        weather = try await weatherManager.weather(at: date, for: location)
      }
      catch {
        logError("Error getting weather: \(error)")
      }
    }
    else {
      logWarning("Location was nil - not fetching weather.")
    }
    
    // Get the health kit data
    let interval = DateInterval(start: date.addingTimeInterval(-86400.0), end: date)
    let healthKitData = healthKitManager.readHealthKitData(in: interval, inWidget: inWidget)
    
    // Return the model input
    return ModelInput(date: date, location: location, weatherStatistics: weather?.statistics, healthKitData: healthKitData)
  }
  
  /// Gets classifier input appropriate for prediction, saves it as training
  /// data, runs a prediction, and evaluates the prediction.
  ///
  /// - Parameters:
  ///   - create: Set to true if the headache manager should create training
  ///     data with the prediction.
  ///   - predict: Runs a prediction before returning the input if true.
  ///   - inWidget: Whether this method is being called by a widget.
  func createPredict(create: Bool = true, predict: Bool = true, inWidget: Bool) async throws {
    let input = await predictorInput(atDate: Date(), inWidget: inWidget)
    
    if create {
      let identifier = try await currentSeverityIdentifier()
      try await createTrainingData(from: input, severityIdentifier: identifier)
    }
    
    if predict {
      let prediction = try await predictor.predict(input, inWidget: inWidget)
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
  ///   - replacingExistingData: Whether the severity's existing training data should be replaced with the new data.
  func createTrainingData(from input: ModelInput, severityIdentifier: UUID? = nil, replacingExistingData: Bool = false) async throws {
    logInfo("Creating training data...")
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Create the training data
      let trainingData = TrainingData(context: context, input: input)
      logDebug("Created training data.")
      
      if let severityIdentifier = severityIdentifier {
        let request = SeverityState.fetchRequest(withIdentifier: severityIdentifier)
        if let severity = ((try? context.fetch(request)) ?? []).first {
          if replacingExistingData {
            if let existingTrainingData = severity.trainingData {
              for data in existingTrainingData {
                guard let uData = data as? TrainingData else { continue }
                severity.removeFromTrainingData(uData)
                context.delete(uData)
              }
            }
          }
          
          severity.addToTrainingData(trainingData)
        }
        else {
          logWarning("Unable to add training data to severity with identifier: \(severityIdentifier.uuidString)")
        }
      }
    }
  }
  
  /// Upgrades the app's training data.
  ///
  /// Rows to upgrade are collected in a read pass, the replacement health and
  /// weather values are fetched outside of any managed object context, and a
  /// final write pass applies them. Blocking a context's queue while awaiting
  /// work on that same queue deadlocks, so no context is held while fetching.
  func upgradeTrainingData() async throws {
    logInfo("Upgrading health kit training data.")
    let healthUpgradeTargets: [(NSManagedObjectID, Date)] = try await trainingData(predicate: NSPredicate(format: "(healthData.version != %@) OR (healthData.version == %@)", Constants.trainingDataVersion as NSString, NSNull())) { trainingData, _ in
      return trainingData.compactMap { trainingDatum in
        guard let timestamp = trainingDatum.timestamp else {
          return nil
        }
        return (trainingDatum.objectID, timestamp)
      }
    }

    logInfo("Performing upgrade on \(healthUpgradeTargets.count) data.")
    var healthUpdates = [(NSManagedObjectID, [HealthKitData: Double], Date)]()
    for (objectID, timestamp) in healthUpgradeTargets {
      let interval = DateInterval(start: timestamp.addingTimeInterval(-86400.0), end: timestamp)
      if let data = healthKitManager.readHealthKitData(in: interval) {
        healthUpdates.append((objectID, data, timestamp))
      }
    }

    if !healthUpdates.isEmpty {
      try await DataController.shared.performInBackground(saveOnComplete: true) { context in
        for (objectID, data, timestamp) in healthUpdates {
          guard let trainingDatum = try? context.existingObject(with: objectID) as? TrainingData else {
            continue
          }
          trainingDatum.updateWithHealthKitData(data, at: timestamp)
        }
      }
    }
    logDebug("Finished upgrading health kit training data.")

    logInfo("Upgrading weather training data.")
    let weatherUpgradeTargets: [(NSManagedObjectID, Date)] = try await trainingData(predicate: NSPredicate(format: "(weatherData.version != %@) OR (weatherData.version == %@)", Constants.trainingDataWeatherVersion as NSString, NSNull())) { trainingData, _ in
      return trainingData.compactMap { trainingDatum in
        guard let timestamp = trainingDatum.timestamp else {
          return nil
        }
        return (trainingDatum.objectID, timestamp)
      }
    }

    logInfo("Performing weather upgrade on \(weatherUpgradeTargets.count) data.")
    var weatherUpdates = [(NSManagedObjectID, WeatherStatistics, Date)]()
    for (objectID, timestamp) in weatherUpgradeTargets {
      do {
        let location = try await locationManager.location()
        let weather = try await weatherManager.weather(at: timestamp, for: location)
        weatherUpdates.append((objectID, weather.statistics, timestamp))
      }
      catch {
        logError("Error upgrading weather: \(error)")
      }
    }

    if !weatherUpdates.isEmpty {
      try await DataController.shared.performInBackground(saveOnComplete: true) { context in
        for (objectID, statistics, timestamp) in weatherUpdates {
          guard let trainingDatum = try? context.existingObject(with: objectID) as? TrainingData else {
            continue
          }
          trainingDatum.updateWithWeatherStatistics(statistics, at: timestamp)
        }
      }
    }
    logDebug("Finished upgrading weather training data.")
  }
  
  /// Trains the classifiers.
  func trainClassifiers() async throws {
    // Build the training input inside the context block; the input holds
    // context-free data tables, so training itself runs outside of it.
    let input = try await trainingData(predicate: NSPredicate(format: "(healthData.version == %@) AND (weatherData.version == %@)", Constants.trainingDataVersion as NSString, Constants.trainingDataWeatherVersion as NSString)) { trainingData, _ -> TrainingInput in
      let trimmedTrainingData = HeadacheManager.trimmedTrainingData(trainingData)
      logDebug("Training classifiers with \(trimmedTrainingData.count) data...")
      return try TrainingInput(trainingData: trimmedTrainingData)
    }

    try await predictor.train(input)
  }

  /// Balances the ratio of not-present training data to headache training data.
  ///
  /// - Parameter trainingData: The training data to trim.
  /// - Returns: The trimmed training data.
  static func trimmedTrainingData(_ trainingData: [TrainingData]) -> [TrainingData] {
    var notPresentTrainingData = trainingData.filter({ $0.severity?.severity == .notPresent || $0.severity?.severity == nil })
    var notNotPresentTrainingData = trainingData.filter({ $0.severity?.severity != .notPresent && $0.severity?.severity != nil })

    notPresentTrainingData.shuffle()
    notNotPresentTrainingData.shuffle()

    let maxNotPresent = notNotPresentTrainingData.count < 50 ? notNotPresentTrainingData.count * 2 : notNotPresentTrainingData.count
    if notPresentTrainingData.count > maxNotPresent {
      notPresentTrainingData.removeLast(notPresentTrainingData.count - maxNotPresent)
    }

    return notPresentTrainingData + notNotPresentTrainingData
  }
  
  /// Evaluates the prediction and saves it to core data.
  ///
  /// - Parameter prediction: The prediction.
  private func evaluatePrediction(_ prediction: PredictionOutput) async throws {
    let hasCurrent = try await hasCurrentHeadache()
    let severity = try await currentHeadache { headache, _ in
      return headache?.severity ?? .notPresent
    }
    
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let evaluation = Evaluation(context: context)
      evaluation.timestamp = Date()
      evaluation.outlook = (hasCurrent && prediction.outlookClassifierOutput.prediction == .headache) || (!hasCurrent && prediction.outlookClassifierOutput.prediction == .noHeadache)
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
