//
//  LogSeverityIntent.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import AppIntents
import Foundation

/// Logs a severity from a widget tap.
///
/// `LiveActivityIntent` conformance makes the intent execute in the app's
/// process (launched in the background if needed), so the full
/// `changeSeverity` flow — Core Data, HealthKit mirroring, widget defaults,
/// training data — runs exactly as an in-app tap would.
struct LogSeverityIntent: LiveActivityIntent {

  static var title: LocalizedStringResource = "Log Severity"

  /// Hidden from Shortcuts; the discoverable phrasing lives on
  /// `LogHeadacheIntent`.
  static var isDiscoverable = false

  @Parameter(title: "Severity")
  var severity: SeverityAppEnum

  init() {}

  init(severity: SeverityAppEnum) {
    self.severity = severity
  }

  func perform() async throws -> some IntentResult {
    let targetSeverity = severity.headacheSeverity

    // No-op when the tapped severity is already current.
    guard Preferences.Shared().currentSeverity != targetSeverity else {
      return .result()
    }

    let manager = HeadacheManager()
    try await manager.changeSeverity(to: targetSeverity)

    // Schedule the follow-up check-in the same way an in-app change does.
    let preferences = Preferences.Notifications()
    if preferences.checkInAlerts, targetSeverity != .notPresent,
       let headacheIdentifier = try await manager.currentHeadacheIdentifier() {
      try await AlertManager().scheduleCheckInAlert(
        headacheIdentifier: headacheIdentifier,
        interval: preferences.checkInInterval)
    }

    return .result()
  }

}
