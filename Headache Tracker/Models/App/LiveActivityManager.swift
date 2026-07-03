//
//  LiveActivityManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import ActivityKit
import Foundation

/// Keeps the headache Live Activity in sync with the store.
///
/// Everything goes through `reconcile`, which starts, updates, or ends the
/// activity to match the current headache — so edits, deletes, widget taps,
/// and the >8h activity lifetime are all handled by re-running it.
class LiveActivityManager {

  /// The shared manager.
  static let shared = LiveActivityManager()

  /// How long the activity's content stays fresh. iOS ends activities on
  /// its own after ~12h; the stale date dims ours first.
  private static let staleInterval: TimeInterval = 12.0 * 3600.0

  private init() {}

  // MARK: Public methods

  /// Reconciles the Live Activity with the current headache.
  ///
  /// - Parameter headacheManager: The manager to read the current headache
  ///   from.
  @MainActor func reconcile(headacheManager: HeadacheManager) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      return
    }

    do {
      let start = try await headacheManager.currentHeadacheStart()
      let severity = Preferences.Shared().currentSeverity

      if let start = start, let severity = severity, severity != .notPresent {
        await startOrUpdate(startDate: start, severity: severity)
      }
      else {
        await endAll()
      }
    }
    catch {
      logError("Error reconciling Live Activity: \(error)")
    }
  }

  // MARK: Private methods

  /// Starts a new activity or updates the existing one.
  private func startOrUpdate(startDate: Date, severity: Headache.Severity) async {
    let state = HeadacheActivityAttributes.ContentState(severityRawValue: severity.rawValue, lastUpdate: Date())
    let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleInterval))

    // Update in place when the activity matches the current headache; end
    // stragglers (there should never be more than one).
    if let activity = Activity<HeadacheActivityAttributes>.activities.first(where: { $0.attributes.startDate == startDate }) {
      await activity.update(content)
      for extra in Activity<HeadacheActivityAttributes>.activities where extra.id != activity.id {
        await extra.end(nil, dismissalPolicy: .immediate)
      }
      return
    }

    // The onset changed (edit) or no activity exists: restart.
    await endAll()
    do {
      _ = try Activity.request(attributes: HeadacheActivityAttributes(startDate: startDate), content: content)
      logDebug("Started Live Activity for headache starting \(startDate).")
    }
    catch {
      logError("Error starting Live Activity: \(error)")
    }
  }

  /// Ends every headache activity.
  private func endAll() async {
    for activity in Activity<HeadacheActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

}
