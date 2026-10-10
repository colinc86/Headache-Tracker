//
//  WatchConnectivityProvider.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import Foundation
import WatchConnectivity

/// The phone side of wrist quick-logging: receives a severity from the watch
/// and runs the real `changeSeverity` flow (Core Data + HealthKit + training
/// + Live Activity), exactly like an in-app or widget tap.
final class WatchConnectivityProvider: NSObject, WCSessionDelegate {

  /// Must match `WatchConnectivityClient.severityMessageKey` on the watch.
  static let severityMessageKey = "severity"

  /// The shared provider.
  static let shared = WatchConnectivityProvider()

  private override init() {
    super.init()
  }

  /// Activates the session when a paired watch is possible.
  func activate() {
    guard WCSession.isSupported() else {
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  // MARK: Logging

  private func handle(_ payload: [String: Any]) {
    guard let raw = payload[Self.severityMessageKey] as? Int,
          let severity = Headache.Severity(rawValue: raw) else {
      return
    }
    Task { await Self.log(severity) }
  }

  /// Performs the severity change on the phone, mirroring `LogSeverityIntent`.
  static func log(_ severity: Headache.Severity) async {
    guard Preferences.Shared().currentSeverity != severity else {
      return
    }

    let manager = HeadacheManager()
    do {
      try await manager.changeSeverity(to: severity)

      let preferences = Preferences.Notifications()
      if severity == .notPresent {
        AlertManager().removePendingRequests(withIdentifiers: [HeadacheAlertRequest.checkInRequestIdentifier])
      }
      else if preferences.checkInAlerts,
              let headacheIdentifier = try await manager.currentHeadacheIdentifier() {
        try await AlertManager().scheduleCheckInAlert(
          headacheIdentifier: headacheIdentifier,
          interval: preferences.checkInInterval)
      }

      await LiveActivityManager.shared.reconcile(headacheManager: manager)

      // Echo the resulting state back so the watch's home view and
      // complication reflect the change it just made.
      WatchConnectivityProvider.shared.syncStateToWatch()
    }
    catch {
      logError("Error logging severity from watch: \(error)")
    }
  }

  // MARK: State push

  /// Pushes the latest forecast + active severity to the paired watch so its
  /// home view and complication can render without the phone's model layer.
  ///
  /// App-group `UserDefaults` never syncs across devices, so this
  /// WatchConnectivity push is the *only* thing that populates the watch's
  /// copy of `currentRisk`/`currentSeverity`. `updateApplicationContext` is
  /// coalesced, latest-wins, delivered in the background, and a harmless no-op
  /// when no watch is paired — so this is purely additive.
  func syncStateToWatch() {
    guard WCSession.isSupported() else {
      return
    }
    let session = WCSession.default
    guard session.activationState == .activated,
          session.isPaired,
          session.isWatchAppInstalled else {
      return
    }

    // Forward the exact bytes/keys the watch reads (`WatchShared`): the risk
    // JSON blob and the severity's raw Int, both plist types.
    var context: [String: Any] = [:]
    if let riskData = UserDefaults.shared?.data(forKey: Preferences.Shared.Keys.currentRisk) {
      context[Preferences.Shared.Keys.currentRisk] = riskData
    }
    if let severity = UserDefaults.shared?.object(forKey: Preferences.Shared.Keys.currentSeverity) as? Int {
      context[Preferences.Shared.Keys.currentSeverity] = severity
    }

    // `updateApplicationContext` rejects an empty dictionary; nothing to sync
    // means the watch simply keeps its last-known (also-empty) state.
    guard !context.isEmpty else {
      return
    }

    do {
      try session.updateApplicationContext(context)
    }
    catch {
      logError("Error syncing state to watch: \(error)")
    }
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    // Push the current state as soon as the session is ready (covers app
    // launch / foreground).
    if activationState == .activated {
      syncStateToWatch()
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Reactivate to keep receiving after a watch switch.
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    handle(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    handle(userInfo)
  }

}
