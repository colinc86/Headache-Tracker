//
//  Refresher.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/6/22.
//

import BackgroundTasks
import DataController
import Foundation
import SwiftUI

class Refresher: ObservableObject {
  
  // MARK: Public properties
  
  /// The app's alert manager.
  let alertManager = AlertManager()
  
  /// The app's headache manager.
  weak var headacheManager: HeadacheManager!
  
  // MARK: Private properties
  
  /// The check-in alerts setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The check-in interval setting if `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) private var dailyOutlookAlerts = false
  
  /// The daily outlook alert time.
  @AppStorage(AppSettings.dailyOutlookTime) private var dailyOutlookTime = TimeInterval(28800.0)
  
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
  private let predictionRefreshTask = RefreshTask(identifier: Constants.Tasks.backgroundPredictionTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for getting the daily outlook.
  private let outlookRefreshTask = RefreshTask(identifier: Constants.Tasks.backgroundOutlookTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for re-training the machine learning models.
  private let trainingProcessingTask = RefreshTask(identifier: Constants.Tasks.backgroundTrainingTaskIdentifier, type: .processing)
  
  /// The create training data background task.
  private var createTrainingDataBackgroundTask = BackgroundTask(identifier: "createTrainingData")
  
  /// The get current classifier input background task.
  private var getCurrentClassifierInputBackgroundTask = BackgroundTask(identifier: "getCurrentClassifierInput")
  
}

// MARK: Alerting

extension Refresher {
  
  /// Presents a check-in alert in the future.
  ///
  /// - Parameter headacheIdentifier: The headache identifier.
  func presentCheckInAlert(with headacheIdentifier: UUID?) async throws {
    // Only continue if we have an identifier and check-in alerts are turned on
    guard checkInAlerts, let headacheIdentifier = headacheIdentifier else {
      return
    }
    
    // Cancel any pending notifications
    alertManager.removeRequests(pending: true, delivered: false)
    
    // Get our date components
    let futureDate = Date(timeIntervalSinceNow: checkInInterval)
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)
    
    // Present the alert
    logDebug("Presenting alert with components at date \(futureDate).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.checkIn(headacheIdentifier: headacheIdentifier),
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
      badgeNumber: 0)
  }
  
  /// Presents a prediction alert now.
  ///
  /// - Parameter prediction: The prediction.
  func presentPredictionAlert(with prediction: Predictor.Prediction?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard realTimeAlerts, let prediction = prediction,
          prediction.severityClassifierOutput.prediction != .notPresent &&
            prediction.outlookClassifierOutput.prediction == .headache else {
              return
            }
    
    // Present the alert
    logDebug("Presenting alert for predicted severity: \(prediction.severityClassifierOutput.prediction.title).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.prediction(severity: prediction.severityClassifierOutput.prediction),
      badgeNumber: 0)
  }
  
  /// Presents an outlook alert now.
  ///
  /// - Parameter prediction: The prediction.
  func presentOutlookAlert(with prediction: Predictor.Prediction?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard dailyOutlookAlerts, let prediction = prediction else {
      return
    }
    
    // Present the alert
    logDebug("Presenting alert for outlook: \(prediction.outlookClassifierOutput.prediction).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.outlook(outlook: prediction.outlookClassifierOutput.prediction, onset: prediction.onsetRegressorOutput.prediction),
      badgeNumber: 0)
  }
  
}

// MARK: - Predictions background refresh methods

extension Refresher {
  
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
    Task { [weak self] in
      guard let self = self else { return }
      
      do {
        try await self.schedulePredictionRefreshTask()
      }
      catch {
        logError("Error scheduling prediction refresh task: \(error)")
      }
    }
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.headacheManager?.cancelClassificationInput()
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
    Task { [weak self] in
      guard let self = self else { return }
      
      do {
        let input = try await self.headacheManager.getCurrentClassifierInput()
        
        // Should we create new training data?
        // If it's been more than half an hour then yes.
        if let timestamp = try await self.headacheManager.lastTrainingDataDate(), Date().timeIntervalSince(timestamp) > 1800.0 {
          try await self.headacheManager.createTrainingData(from: input, severityIdentifier: currentSeverityID)
        }
        
        // If there is no current headache, then present a prediction
        if currentSeverityID == nil {
          // We got the input, so present the prediction
          let prediction = try await self.headacheManager.predictor.predict(input)
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

extension Refresher {
  
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
      self?.headacheManager.cancelClassificationInput()
    }
    
    // Run a prediction
    Task { [weak self] in
      guard let self = self else {
        task.setTaskCompleted(success: false)
        return
      }
      
      do {
        let input = try await self.headacheManager.getCurrentClassifierInput()
        try await self.presentOutlookAlert(with: try self.headacheManager.predictor.predict(input))
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

extension Refresher {
  
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
      self?.headacheManager.predictor.cancelTraining()
      task?.setTaskCompleted(success: false)
    }
    
    // Train
    Task { [weak self] in
      guard let self = self else {
        task.setTaskCompleted(success: false)
        return
      }
      
      do {
        if try await self.headacheManager.needsTraining() {
          try await self.headacheManager.trainClassifiers()
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
