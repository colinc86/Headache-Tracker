//
//  RiskActivityManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import ActivityKit
import Foundation

/// Keeps the risk-gauge Live Activity in sync with the current forecast.
///
/// Everything goes through `reconcile`, which starts, updates, or ends the
/// activity to match the latest stored forecast. It is driven from the
/// foreground (app active, after a fresh prediction) — ActivityKit constrains
/// starting activities from the background, so a high-risk window that opens
/// while the app is backgrounded surfaces the next time the app is active.
class RiskActivityManager {

  /// The shared manager.
  static let shared = RiskActivityManager()

  /// How long the activity's content stays fresh before dimming.
  private static let staleInterval: TimeInterval = 12.0 * 3600.0

  private init() {}

  // MARK: Public methods

  /// Reconciles the risk Live Activity with the stored forecast.
  ///
  /// The gauge is shown only when there is no active headache (the headache
  /// activity owns the screen then) and the forecast reads as high risk.
  @MainActor func reconcile() async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      return
    }

    // Respect the real-time alert preference — the gauge is an ambient
    // real-time surface, opt-in alongside nudges.
    guard Preferences.Notifications().realTimeAlerts else {
      await endAll()
      return
    }

    let severity = Preferences.Shared().currentSeverity
    let headacheActive = severity != nil && severity != .notPresent
    let risk = Preferences.Shared().currentRisk

    if !headacheActive, let risk = risk, risk != .empty, risk.tier == .high {
      await startOrUpdate(risk: risk)
    }
    else {
      await endAll()
    }
  }

  // MARK: Private methods

  /// Starts a new activity or updates the existing one.
  private func startOrUpdate(risk: RiskPrediction) async {
    let state = RiskActivityAttributes.ContentState(
      probability: risk.probability,
      shortProbability: risk.shortProbability,
      computedAt: risk.computedAt)
    let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleInterval))

    // Update in place when an activity already exists; end stragglers.
    if let activity = Activity<RiskActivityAttributes>.activities.first {
      await activity.update(content)
      for extra in Activity<RiskActivityAttributes>.activities where extra.id != activity.id {
        await extra.end(nil, dismissalPolicy: .immediate)
      }
      return
    }

    do {
      _ = try Activity.request(attributes: RiskActivityAttributes(startedAt: Date()), content: content)
      logDebug("Started risk Live Activity at \(Int((risk.probability * 100).rounded()))%.")
    }
    catch {
      logError("Error starting risk Live Activity: \(error)")
    }
  }

  /// Ends every risk activity.
  private func endAll() async {
    for activity in Activity<RiskActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

}
