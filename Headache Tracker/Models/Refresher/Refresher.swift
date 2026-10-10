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
    
    try await alertManager.scheduleCheckInAlert(
      headacheIdentifier: headacheIdentifier,
      interval: preferences.notifications.checkInInterval)
  }
  
  /// Presents a high-risk alert now, debounced so consecutive refreshes
  /// don't repeat it.
  ///
  /// - Parameter prediction: The prediction.
  func presentRiskAlert(with prediction: RiskPrediction?) async throws {
    // Only continue if alerts are on and risk is high
    guard preferences.notifications.realTimeAlerts,
          let prediction = prediction,
          prediction != .empty,
          prediction.tier == .high else {
      return
    }

    // Debounce: at most one high-risk alert per six hours.
    if let last = preferences.debug.lastRiskAlertDate, Date().timeIntervalSince(last) < 6.0 * 3600.0 {
      return
    }

    // Present the alert
    logDebug("Presenting high risk alert: \(prediction.probability).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.risk(probability: prediction.probability),
      badgeNumber: 0)
    preferences.debug.lastRiskAlertDate = Date()
  }
  
  /// Presents a preemptive nudge when risk is *elevated* (but not yet high),
  /// with a caring, actionable reason drawn from the morning-brief builder.
  /// Debounced via `lastNudgeDate` so consecutive refreshes don't repeat it.
  ///
  /// - Parameter prediction: The prediction.
  func presentElevatedRiskNudge(with prediction: RiskPrediction?) async throws {
    // Only continue if real-time alerts are on and risk is specifically
    // elevated — the high tier is handled by `presentRiskAlert`. Skip when the
    // morning brief is due: it fires later in this same refresh and already
    // conveys the elevated risk, so a nudge here would just double up.
    guard preferences.notifications.realTimeAlerts,
          !isMorningBriefDue,
          let prediction = prediction,
          prediction != .empty,
          prediction.tier == .elevated else {
      return
    }

    // Debounce: at most one nudge per six hours.
    if let last = preferences.debug.lastNudgeDate, Date().timeIntervalSince(last) < 6.0 * 3600.0 {
      return
    }

    let brief = RiskBriefBuilder.makeBrief(
      risk: prediction,
      todayValues: prediction.input.correlationValues(),
      report: InsightsStore.shared.load())

    logDebug("Presenting elevated-risk nudge: \(prediction.probability).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.elevatedRisk(probability: prediction.probability, reasons: brief?.reasons ?? []),
      badgeNumber: 0)
    preferences.debug.lastNudgeDate = Date()
  }

  /// Presents the morning brief now: the risk tier plus the strongest
  /// baseline-deviation reasons.
  ///
  /// - Parameter prediction: The prediction.
  /// - Returns: Whether the brief was actually presented.
  @discardableResult
  func presentMorningBrief(with prediction: RiskPrediction?) async throws -> Bool {
    // Only continue if we have a prediction and brief alerts are turned on
    guard preferences.notifications.dailyOutlookAlerts, let prediction = prediction, prediction != .empty else {
      return false
    }

    let brief = RiskBriefBuilder.makeBrief(
      risk: prediction,
      todayValues: prediction.input.correlationValues(),
      report: InsightsStore.shared.load())

    // Present the alert
    logDebug("Presenting morning brief: \(prediction.probability).")
    try await alertManager.presentAlert(
      with: HeadacheAlertRequest.morningBrief(tier: prediction.tier, probability: prediction.probability, reasons: brief?.reasons ?? []),
      badgeNumber: 0)
    return true
  }

  /// Whether the morning brief is due: brief alerts are on, today's brief
  /// time has passed, and no brief was presented since.
  var isMorningBriefDue: Bool {
    guard preferences.notifications.dailyOutlookAlerts else {
      return false
    }

    let now = Date()
    let todaysOutlookDate = Calendar.current.startOfDay(for: now).addingTimeInterval(preferences.notifications.dailyOutlookTime)
    return now >= todaysOutlookDate && (preferences.debug.lastOutlookDate ?? .distantPast) < todaysOutlookDate
  }

  /// Presents the morning brief if it's due.
  ///
  /// The day's slot is consumed only after the alert is actually presented,
  /// so a failed presentation is retried on the next refresh.
  ///
  /// - Parameter prediction: The prediction.
  func presentMorningBriefIfNeeded(with prediction: RiskPrediction?) async throws {
    guard isMorningBriefDue, prediction != nil else {
      return
    }

    // Consume the day's slot only when a brief was actually presented —
    // an empty prediction (e.g. right after a model reset) declines
    // silently and should retry on the next refresh.
    guard try await presentMorningBrief(with: prediction) else {
      return
    }

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

        // Sample a training row on the clock. The manager drops it when a
        // row already exists within its dedupe window, which also covers
        // the zero-row case on a fresh install.
        try await self.headacheManager.createTrainingData(from: input, source: .background)

        // Score any matured forecasts before recording a new one.
        try await self.headacheManager.resolveEvaluations()

        // Run a prediction when there's no current headache, or when the
        // daily outlook is due (which must fire even during a headache).
        if currentSeverityID == nil || self.isMorningBriefDue {
          let prediction = try await self.headacheManager.predictor.predict(input, inWidget: false)

          if currentSeverityID == nil {
            // Record the forecast so the prospective accuracy record covers
            // every hour, not only the hours the app was opened.
            if prediction != .empty {
              try await self.headacheManager.recordEvaluation(for: prediction)
            }

            try await self.presentRiskAlert(with: prediction)
            try await self.presentElevatedRiskNudge(with: prediction)
          }

          // Present the morning brief when due
          try await self.presentMorningBriefIfNeeded(with: prediction)
        }

        // Push the freshly computed forecast to the watch (app groups don't
        // sync across devices, so this is the only path that reaches it).
        WatchConnectivityProvider.shared.syncStateToWatch()

        completion.complete(success: true)
      }
      catch {
        // This block spans input assembly, training-data creation, prediction,
        // and every alert presentation — so attribute the failure to the whole
        // refresh, not just training data.
        logError("Error handling prediction refresh task: \(error)")
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
