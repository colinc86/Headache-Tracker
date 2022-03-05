//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import BackgroundTasks
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
  
  // MARK: Weak properties
  
  /// The alert manager to use when adding local notifications.
  weak var alertManager: AlertManager?
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  weak var healthKitManager: HealthKitManager?
  
  /// The manager's weather manager.
  weak var weatherManager: WeatherManager?
  
  /// The headache predictor.
  weak var predictor: Predictor?
  
  // MARK: Private properties
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The check-in alerts setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) private var dailyOutlookAlerts = false
  
  /// The daily outlook alert time.
  @AppStorage(AppSettings.dailyOutlookTime) private var dailyOutlookTime = TimeInterval(28800.0)
  
  /// The check-in interval setting if `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastOutlookDate) private var debugLastOutlookDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextOutlookDate) private var debugNextOutlookDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastTrainingDate) private var debugLastTrainingDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextTrainingDate) private var debugNextTrainingDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastPredictionDate) private var debugLastPredictionDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextPredictionDate) private var debugNextPredictionDate: Date?
  
  /// The refresh task responsible for creating background samples.
  private let predictionRefreshTask = RefreshTask(identifier: Constants.Identifiers.backgroundPredictionTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for getting the daily outlook.
  private let outlookRefreshTask = RefreshTask(identifier: Constants.Identifiers.backgroundOutlookTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for re-training the machine learning models.
  private let trainingProcessingTask = RefreshTask(identifier: Constants.Identifiers.backgroundTrainingTaskIdentifier, type: .processing)
  
  /// The create training data background task.
  private var createTrainingDataBackgroundTask = BackgroundTask(identifier: "createTrainingData")
  
  /// The get current classifier input background task.
  private var getCurrentClassifierInputBackgroundTask = BackgroundTask(identifier: "getCurrentClassifierInput")
  
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
    var severityInterval: SeverityInterval?
    
    // The headache's identifier to pass to the local notification
    var headacheIdentifier: UUID?
    
    // The identifier of the severity that was added
    var severityIdentifier: UUID?
    
    try await currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        (severityInterval, severityIdentifier) = headache.addSeverity(severity, startTime: Date())
        headacheIdentifier = headache.identifier
      }
      else {
        logDebug("Creating new headache.")
        let newHeadache = Headache(context: context, initialSeverity: severity, startTime: Date())
        headacheIdentifier = newHeadache.identifier
        severityIdentifier = newHeadache.severitiesArray.first?.identifier
      }
    }
    
    // If there wasn't an error, then update the widget data and continue
    SharedUserDefaults.standard.setCurrentSeverity(severity)
    
    // Write the data to health kit and set our check-in alert
    try await self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
    try await presentCheckInAlert(with: headacheIdentifier)
    
    // Update the CoreML models
    try await createTrainingData(newSeverityIdentifier: severityIdentifier)
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
    
    // Cancel any pending notifications
    alertManager?.removeRequests(pending: true, delivered: false)
    
    // Write the data to health kit
    try await healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
    
    // Update the CoreML models
    try await createTrainingData()
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
      try await healthKitManager?.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime))
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
    
    try await healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!])
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
    
    try await headacheWithIdentifier(identifier: identifier) { [weak self] headache, context in
      logDebug("Deleting headache.")
      
      // Get the headache
      if let headache = headache {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
        
        // If this headache was the current headache, then cancel any pending check-in notifications
        // and reset the current severity.
        if !headache.resolved {
          self?.alertManager?.removeRequests(pending: true, delivered: false)
          SharedUserDefaults.standard.setCurrentSeverity(nil)
        }
      }
    }
    
    // If there wasn't an error, then we should check and delete it from health kit
    if let startTime = startTime, let endTime = endTime {
      logDebug("Successfully reset headache. Deleting severity samples.")
      try await healthKitManager?.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime))
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
      try await healthKitManager?.deleteSeveritySamples(in: originalHeadacheInterval)
      try await healthKitManager?.saveSeveritySamples(intervals: newSeveritySamples)
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
      try await self.healthKitManager?.deleteSeveritySamples(in: originalHeadacheInterval)
      try await self.healthKitManager?.saveSeveritySamples(intervals: newSeveritySamples)
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
  ///   - update: Called with the training data to update it. Errors thrown in
  ///     this block will be received in completion.
  private func trainingData<T>(predicate: NSPredicate? = nil, update: @escaping ([TrainingData], NSManagedObjectContext) throws -> T) async throws -> T {
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      request.predicate = predicate
      return try update(try context.fetch(request), context)
    }
  }
  
}

// MARK: - Alerting

extension HeadacheManager {
  
  /// Presents a check-in alert in the future.
  ///
  /// - Parameter headacheIdentifier: The headache identifier.
  private func presentCheckInAlert(with headacheIdentifier: UUID?) async throws {
    // Only continue if we have an identifier and check-in alerts are turned on
    guard checkInAlerts, let headacheIdentifier = headacheIdentifier else {
      return
    }
    
    // Cancel any pending notifications
    alertManager?.removeRequests(pending: true, delivered: false)
    
    // Get our date components
    let futureDate = Date(timeIntervalSinceNow: self.checkInInterval)
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)
    
    // Present the alert
    logDebug("Presenting alert with components at date \(futureDate).")
    try await alertManager?.presentAlert(
      with: HeadacheAlertRequest.checkIn(headacheIdentifier: headacheIdentifier),
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
      badgeNumber: 0)
  }
  
  /// Presents a prediction alert now.
  ///
  /// - Parameter prediction: The prediction.
  private func presentPredictionAlert(with prediction: Predictor.Prediction?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard realTimeAlerts, let prediction = prediction,
            prediction.severityClassifierOutput.prediction != .notPresent &&
            prediction.outlookClassifierOutput.prediction == .headache else {
      return
    }
    
    // Present the alert
    logDebug("Presenting alert for predicted severity: \(prediction.severityClassifierOutput.prediction.title).")
    try await alertManager?.presentAlert(
      with: HeadacheAlertRequest.prediction(severity: prediction.severityClassifierOutput.prediction),
      badgeNumber: 0)
  }
  
  /// Presents an outlook alert now.
  ///
  /// - Parameter prediction: The prediction.
  private func presentOutlookAlert(with prediction: Predictor.Prediction?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard dailyOutlookAlerts, let prediction = prediction else {
      return
    }
    
    // Present the alert
    logDebug("Presenting alert for outlook: \(prediction.outlookClassifierOutput.prediction).")
    try await self.alertManager?.presentAlert(
      with: HeadacheAlertRequest.outlook(outlook: prediction.outlookClassifierOutput.prediction, onset: prediction.onsetRegressorOutput.prediction),
      badgeNumber: 0)
  }
  
}

// MARK: Prediction

extension HeadacheManager {
  
  /// Resets all prediction and learning data.
  func resetPrediction() {
    predictor?.reset()
  }
  
  /// Whether or not the application needs more not present training data.
  ///
  /// - Returns: A boolean indicating if the app should ask for more training data.
  func needsNotPresentTrainingData() async throws -> Bool {
    return try await trainingData { trainingData, _ in
      let notPresentTrainigData = trainingData.filter({ $0.severity == nil || $0.severity?.severity == .notPresent })
      
      var nextDateAllowed = false
      if let lastNotPresentDate = notPresentTrainigData.last?.timestamp {
        nextDateAllowed = Date().timeIntervalSince(lastNotPresentDate) > 3600.0 // Every 1 hour
      }
      
      return nextDateAllowed
    }
  }
  
  /// Whether or not the device contains training data that's newer than
  /// the latest compiled models.
  ///
  /// - Returns: A boolean indicating if the app needs to train its models.
  func needsTraining() async throws -> Bool {
    return try await trainingData { trainingData, _ in
      var needs = false
      if let date = trainingData.last?.timestamp, let lastTrainingDate = self.predictor?.modelUpdatedAt {
        needs = date.timeIntervalSince(lastTrainingDate) > 0.0
      }
      
      return needs
    }
  }
  
  /// Cancels the current classification input reading.
  func cancelClassificationInput() {
    weatherManager?.cancel()
  }
  
  /// Gets classifier input appropriate for prediction.
  ///
  /// - Parameter shouldCreateTrainingData: Set to true if the headache manager should
  ///   create training data as a reesult of getting the classifier input.
  func getCurrentClassifierInput(shouldCreateTrainingData: Bool = false) async throws -> Predictor.Input {
    guard !testing else { throw HeadacheError.testing }
    
    defer { getCurrentClassifierInputBackgroundTask.end() }
    getCurrentClassifierInputBackgroundTask.begin { [weak self] in
      self?.weatherManager?.cancel()
    }
    
    let weather = try await weatherManager?.weather()
    let now = Date()
    let interval = DateInterval(start: now.addingTimeInterval(-86400.0), end: now)
    let healthKitData = self.healthKitManager?.readHealthKitData(in: interval)
    return Predictor.Input(weather: weather, healthKitData: healthKitData, date: now)
  }
  
  /// Create new training data and sets its `severity` relationship to the severity
  /// with the given identifier. If no identifier is present, then the training data is
  /// still created but orphaned (a not-present severity).
  ///
  /// - Parameter newSeverityIdentifier: The new severity identifier.
  @discardableResult
  func createTrainingData(newSeverityIdentifier: UUID? = nil) async throws -> Predictor.Input {
    guard !testing else { throw HeadacheError.testing }

    logDebug("Create training data background task begin.")
    defer { createTrainingDataBackgroundTask.end() }
    createTrainingDataBackgroundTask.begin { [weak self] in
      self?.weatherManager?.cancel()
    }

    // Get the barometric pressure
    logDebug("Getting input...")
    let input = try await getCurrentClassifierInput()
    
    logInfo("Creating training data...")
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Create the training data
      let trainingData = TrainingData(context: context, input: input)
      logDebug("Created training data.")
      
      if let newSeverityIdentifier = newSeverityIdentifier {
        logDebug("Setting training data on severity \(newSeverityIdentifier)")
        let request = Severity.fetchRequest(withIdentifier: newSeverityIdentifier)
        if let severity = ((try? context.fetch(request)) ?? []).first {
          severity.addToTrainingData(trainingData)
        }
        else {
          logWarning("Unable to add training data to severity with identifier: \(newSeverityIdentifier.uuidString)")
        }
      }
    }
    
    return input
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
        let data = self?.healthKitManager?.readHealthKitData(in: interval)
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
    try await trainingData(predicate: NSPredicate(format: "version == %@", Constants.trainingDataVersion as NSString)) { [weak self] trainingData, _ in
      guard let self = self else {
        return
      }
      
      logDebug("Training classifiers with \(trainingData.count) data...")
      Task {
        do {
          try await self.predictor?.train(with: trainingData)
        }
        catch {
          logError("Error training classifiers: \(error)")
        }
      }
    }
  }
  
}

// MARK: - Predictions background refresh methods

extension HeadacheManager {
  
  /// Sets up the refresh task by registering it.
  func setupPredictionRefreshTask() {
    logDebug("Registering prediction refresh task handler.")
    predictionRefreshTask.register(handlePredictionRefreshTask)
  }
  
  /// Cancels the refresh task.
  func cancelPredictionRefreshTask() {
    logDebug("Cancelling prediction refresh task.")
    predictionRefreshTask.cancel()
  }
  
  /// Schedules the refresh task for the next hour.
  @MainActor func schedulePredictionRefreshTask() async throws {
    // Get the current seconds past midnight.
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(Date())
    
    // Get the number of seconds past the hour
    let secondsPastHour = secondsPastMidnight - TimeInterval(3600 * Int(floor(secondsPastMidnight / 3600.0)))
    
    // Get the number of seconds until the next hour
    var secondsUntilNextHour = 3600.0 - secondsPastHour
    if secondsPastHour > 3540.0 {
      secondsUntilNextHour += 3600.0
    }
    
    // Schedule the next task
    logDebug("Scheduling prediction refresh task with date \(Date(timeIntervalSinceNow: secondsUntilNextHour))")
    try await predictionRefreshTask.schedule(interval: secondsUntilNextHour)
    
    logDebug("Successfully scheduled prediction refresh task.")
    debugNextPredictionDate = Date(timeIntervalSinceNow: secondsUntilNextHour)
  }
  
  /// Handles the refresh task.
  private func handlePredictionRefreshTask(_ task: BGTask) {
    logDebug("Handle prediction refresh task.")
    debugLastPredictionDate = Date()
    
    // Schedule the next task
    Task {
      do {
        try await schedulePredictionRefreshTask()
      }
      catch {
        logError("Error scheduling prediction refresh task: \(error)")
      }
    }
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.cancelClassificationInput()
    }
    
    // Get the current severity identifier
    let context = DataController.shared.newNestedBackgroundContext()
    let currentSeverityID: UUID? = context.performAndWait { [weak context] in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: false))
      let headache = (try? context?.fetch(request))?.last
      return headache?.currentSeverity?.identifier
    }
    
    // Get the input and either alert or finish
    Task {
      do {
        let input = try await createTrainingData(newSeverityIdentifier: currentSeverityID)
        
        if currentSeverityID == nil {
          // We got the input, so present the prediction
          let prediction = try self.predictor?.predict(input)
          try await self.presentPredictionAlert(with: prediction)
        }
        
        task.setTaskCompleted(success: true)
      }
      catch {
        logError("Error creating training data: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
  }
  
}

// MARK: - Daily outlook background refresh methods

extension HeadacheManager {
  
  /// Sets up the refresh task by registering it.
  func setupOutlookRefreshTask() {
    logDebug("Registering outlook refresh task handler.")
    outlookRefreshTask.register(handleOutlookRefreshTask)
  }
  
  /// Cancels the refresh task.
  func cancelOutlookRefreshTask() {
    logDebug("Cancelling outlook refresh task.")
    outlookRefreshTask.cancel()
  }
  
  /// Schedules the outlook task for the daily outlook time.
  @MainActor func scheduleOutlookRefreshTask() async throws {
    // Get the number of seconds past midnight.
    let now = Date()
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(now)
    
    // Get the number of seconds until the next outlook time
    var secondsUntilOutlook: TimeInterval = 0.0
    
    // Are we past the daily outlook time?
    if secondsPastMidnight < dailyOutlookTime {
      // We haven't passed the outlook time yet.
      secondsUntilOutlook = dailyOutlookTime - secondsPastMidnight
    }
    else {
      // We've already passed the outlook time.
      let futureOutlookDate = Calendar.current.midnightAfter(now).addingTimeInterval(dailyOutlookTime)
      secondsUntilOutlook = futureOutlookDate.timeIntervalSince(now)
    }
    
    // Schedule the outlook task
    logDebug("Scheduling outlook refresh task with date \(Date(timeIntervalSinceNow: secondsUntilOutlook)).")
    try await outlookRefreshTask.schedule(interval: secondsUntilOutlook)
    
    logDebug("Successfully scheduled outlook refresh task.")
    debugNextOutlookDate = Date(timeIntervalSinceNow: secondsUntilOutlook)
  }
  
  /// Handles the refresh task.
  private func handleOutlookRefreshTask(_ task: BGTask) {
    logDebug("Handle outlook refresh task.")
    debugLastOutlookDate = Date()
    
    // Schedule the next task
    if dailyOutlookAlerts {
      Task {
        do {
          try await scheduleOutlookRefreshTask()
        }
        catch {
          logError("Error scheduling outlook refresh task: \(error)")
        }
      }
    }
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.cancelClassificationInput()
    }
    
    // Run a prediction
    Task { [weak self] in
      do {
        let input = try await getCurrentClassifierInput()
        try await presentOutlookAlert(with: try self?.predictor?.predict(input))
        task.setTaskCompleted(success: true)
      }
      catch {
        logError("Error getting current classifier input: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
  }
  
}

// MARK: Training background processing methods

extension HeadacheManager {
  
  /// Sets up the processing task by registering it.
  func setupTrainingProcessingTask() {
    logDebug("Registering training processing task handler.")
    trainingProcessingTask.register(handleTrainingProcessingTask)
  }
  
  /// Cancels the processing task.
  func cancelTrainingProcessingTask() {
    logDebug("Cancelling training processing task.")
    trainingProcessingTask.cancel()
  }
  
  /// Schedulees the processing task.
  @MainActor func scheduleTrainingRefreshTask() async throws {
    // Get the number of seconds past midnight.
    let now = Date()
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(now)
    let dailyTrainingTime: TimeInterval = 60.0 * 60.0 * 5.0
    
    // Get the number of seconds until the next outlook time
    var secondsUntilTraining: TimeInterval = 0.0
    
    // Are we past the daily training time? (5AM)
    if secondsPastMidnight < dailyTrainingTime {
      // We haven't passed the outlook time yet.
      secondsUntilTraining = dailyTrainingTime - secondsPastMidnight
    }
    else {
      // We've already passed the outlook time.
      let futureOutlookDate = Calendar.current.midnightAfter(now).addingTimeInterval(dailyTrainingTime)
      secondsUntilTraining = futureOutlookDate.timeIntervalSince(now)
    }
    
    logDebug("Scheduling training processing task with date \(Date(timeIntervalSinceNow: secondsUntilTraining))")
    try await trainingProcessingTask.schedule(interval: secondsUntilTraining)
    
    logDebug("Successfully scheduled training procecssing task.")
    debugNextTrainingDate = Date(timeIntervalSinceNow: secondsUntilTraining)
  }
  
  /// Handles the processing task.
  private func handleTrainingProcessingTask(_ task: BGTask) {
    logDebug("Handle training processing task.")
    debugLastTrainingDate = Date()
    
    // Schedule the next task
    Task {
      do {
        try await scheduleTrainingRefreshTask()
      }
      catch {
        logError("Error scheduling training processing task: \(error)")
      }
    }
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak task, weak self] in
      // Cancel the prediction
      self?.predictor?.cancelTraining()
      task?.setTaskCompleted(success: false)
    }
    
    // Train
    Task { [weak self] in
      guard let self = self else {
        task.setTaskCompleted(success: false)
        return
      }
      
      do {
        if try await self.needsTraining() {
          try await self.trainClassifiers()
        }
        task.setTaskCompleted(success: true)
      }
      catch {
        logError("Error training classifiers: \(error)")
        task.setTaskCompleted(success: false)
      }
    }
  }
  
}
