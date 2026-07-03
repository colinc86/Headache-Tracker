//
//  Refresher.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/6/22.
//

import BackgroundTasks
import Foundation
import SwiftUI

class Refresher: ObservableObject {
  
  // MARK: Public properties
  
  /// The app's alert manager.
  let alertManager = AlertManager()
  
  /// The app's headache manager.
  weak var headacheManager: HeadacheManager!
  
  // MARK: Private properties
  
  /// The application's preferences.
  private var preferences = Preferences()
  
  /// The refresh task responsible for creating background samples and, when
  /// due, the daily outlook alert. A single app-refresh identifier is used
  /// because iOS budgets refresh opportunities per app; two competing
  /// identifiers meant one rarely fired.
  private let predictionRefreshTask = RefreshTask(identifier: Constants.Tasks.backgroundPredictionTaskIdentifier, type: .appRefresh)

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
    guard preferences.notifications.checkInAlerts, let headacheIdentifier = headacheIdentifier else {
      return
    }
    
    // Cancel any pending notifications
    alertManager.removeRequests(pending: true, delivered: false)
    
    // Get our date components
    let futureDate = Date(timeIntervalSinceNow: preferences.notifications.checkInInterval)
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
  func presentPredictionAlert(with prediction: PredictionOutput?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard preferences.notifications.realTimeAlerts, let prediction = prediction,
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
  func presentOutlookAlert(with prediction: PredictionOutput?) async throws {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard preferences.notifications.dailyOutlookAlerts, let prediction = prediction else {
      return
    }

    // Present the alert
    logDebug("Presenting alert for outlook: \(prediction.outlookClassifierOutput.prediction).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.outlook(outlook: prediction.outlookClassifierOutput.prediction, onset: prediction.onsetRegressorOutput.prediction),
      badgeNumber: 0)
  }

  /// Whether the daily outlook alert is due: outlook alerts are on, today's
  /// outlook time has passed, and no outlook was presented since.
  var isOutlookAlertDue: Bool {
    guard preferences.notifications.dailyOutlookAlerts else {
      return false
    }

    let now = Date()
    let todaysOutlookDate = Calendar.current.startOfDay(for: now).addingTimeInterval(preferences.notifications.dailyOutlookTime)
    return now >= todaysOutlookDate && (preferences.debug.lastOutlookDate ?? .distantPast) < todaysOutlookDate
  }

  /// Presents the daily outlook alert if it's due.
  ///
  /// The day's slot is consumed only after the alert is actually presented,
  /// so a failed presentation is retried on the next refresh.
  ///
  /// - Parameter prediction: The prediction.
  func presentOutlookAlertIfNeeded(with prediction: PredictionOutput?) async throws {
    guard isOutlookAlertDue, prediction != nil else {
      return
    }

    try await presentOutlookAlert(with: prediction)

    let now = Date()
    preferences.debug.lastOutlookDate = now
    preferences.debug.nextOutlookDate = Calendar.current.startOfDay(for: now).addingTimeInterval(preferences.notifications.dailyOutlookTime + 86400.0)
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
    let secondsPerHour: UInt32 = 3600
    let randomSeconds = TimeInterval(arc4random_uniform(secondsPerHour))
    let interval = TimeInterval(secondsPerHour) + randomSeconds
    let futureDate = Date(timeIntervalSinceNow: interval)
    
    // Schedule the next task
    logDebug("Scheduling prediction refresh task with date \(futureDate)")
    try await predictionRefreshTask.schedule(date: futureDate)
    
    logDebug("Successfully scheduled prediction refresh task.")
    preferences.debug.nextPredictionDate = futureDate
  }
  
  /// Handles the refresh task.
  private func handlePredictionRefreshTask(_ task: BGTask) {
    logDebug("Handle prediction refresh task.")
    preferences.debug.lastPredictionDate = Date()

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
    let completion = TaskCompletionGuard(task)
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.headacheManager?.cancelClassificationInput()
      completion.complete(success: false)
    }

    // Get the input and either alert or finish
    Task { [weak self] in
      guard let self = self else {
        completion.complete(success: false)
        return
      }

      do {
        // Get the current severity identifier
        let currentSeverityID = try await self.headacheManager.currentSeverityIdentifier()

        let input = await self.headacheManager.predictorInput(atDate: Date(), inWidget: false)

        // Should we create new training data?
        // If it's been more than half an hour then yes.
        if let timestamp = try await self.headacheManager.lastTrainingDataDate(), Date().timeIntervalSince(timestamp) > 1800.0 {
          try await self.headacheManager.createTrainingData(from: input, severityIdentifier: currentSeverityID)
        }

        // Run a prediction when there's no current headache, or when the
        // daily outlook is due (which must fire even during a headache).
        if currentSeverityID == nil || self.isOutlookAlertDue {
          let prediction = try await self.headacheManager.predictor.predict(input, inWidget: false)

          if currentSeverityID == nil {
            try await self.presentPredictionAlert(with: prediction)
          }

          // Present the daily outlook when due
          try await self.presentOutlookAlertIfNeeded(with: prediction)
        }

        completion.complete(success: true)
      }
      catch {
        logError("Error creating training data: \(error)")
        completion.complete(success: false)
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
    preferences.debug.nextTrainingDate = Date(timeIntervalSinceNow: secondsUntilTraining)
  }
  
  /// Handles the processing task.
  private func handleTrainingProcessingTask(_ task: BGTask) {
    logDebug("Handle training processing task.")
    preferences.debug.lastTrainingDate = Date()
    
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
    let completion = TaskCompletionGuard(task)
    task.expirationHandler = { [weak self] in
      // Cancel the training session
      self?.headacheManager?.predictor.cancelTraining()
      completion.complete(success: false)
    }

    // Train
    Task { [weak self] in
      guard let self = self else {
        completion.complete(success: false)
        return
      }

      do {
        if try await self.headacheManager.needsTraining() {
          try await self.headacheManager.trainClassifiers()
        }
        completion.complete(success: true)
      }
      catch {
        logError("Error training classifiers: \(error)")
        completion.complete(success: false)
      }
    }
  }
  
}
