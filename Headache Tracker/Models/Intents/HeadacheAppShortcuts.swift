//
//  HeadacheAppShortcuts.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import AppIntents
import Foundation

/// Logs a headache (or updates the current one) with a severity.
struct LogHeadacheIntent: AppIntent {

  static var title: LocalizedStringResource = "Log a Headache"
  static var description = IntentDescription("Logs a headache with the given severity, or updates the current one.")

  @Parameter(title: "Severity")
  var severity: SeverityAppEnum

  init() {}

  init(severity: SeverityAppEnum) {
    self.severity = severity
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let targetSeverity = severity.headacheSeverity

    do {
      let manager = HeadacheManager()
      try await manager.changeSeverity(to: targetSeverity)
    }
    catch {
      return .result(dialog: "Sorry, I couldn't log that: \(String(describing: error))")
    }

    if targetSeverity == .notPresent {
      return .result(dialog: "Okay, I've resolved your headache.")
    }
    return .result(dialog: "Logged a \(targetSeverity.title.lowercased()) headache. Feel better soon.")
  }

}

/// Resolves the current headache.
struct ResolveHeadacheIntent: AppIntent {

  static var title: LocalizedStringResource = "Resolve Headache"
  static var description = IntentDescription("Marks the current headache as resolved.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let manager = HeadacheManager()

    guard try await manager.currentHeadacheIdentifier() != nil else {
      return .result(dialog: "You don't have a headache logged right now.")
    }

    do {
      try await manager.resolve()
    }
    catch {
      return .result(dialog: "Sorry, I couldn't resolve it: \(String(describing: error))")
    }

    return .result(dialog: "Done — your headache is resolved.")
  }

}

/// Speaks the current headache risk.
struct HeadacheRiskIntent: AppIntent {

  static var title: LocalizedStringResource = "Headache Risk"
  static var description = IntentDescription("Tells you your current headache risk.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let risk = Preferences.Shared().currentRisk, risk != .empty else {
      return .result(dialog: "I don't have a risk forecast yet. Open the app to make a prediction.")
    }

    let percent = Int((risk.probability * 100.0).rounded())
    return .result(dialog: "Your headache risk is \(risk.tier.title.lowercased()) — a \(percent)% chance in the next 24 hours.")
  }

}

/// The app's Siri shortcut phrases.
struct HeadacheAppShortcuts: AppShortcutsProvider {

  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogHeadacheIntent(),
      phrases: [
        "Log a headache in \(.applicationName)",
        "Log a \(\.$severity) headache in \(.applicationName)",
        "I have a headache in \(.applicationName)"
      ],
      shortTitle: "Log Headache",
      systemImageName: "brain.head.profile")

    AppShortcut(
      intent: ResolveHeadacheIntent(),
      phrases: [
        "Resolve my headache in \(.applicationName)",
        "My headache is gone in \(.applicationName)"
      ],
      shortTitle: "Resolve",
      systemImageName: "face.smiling")

    AppShortcut(
      intent: HeadacheRiskIntent(),
      phrases: [
        "What's my headache risk in \(.applicationName)",
        "Check my headache risk in \(.applicationName)"
      ],
      shortTitle: "Risk",
      systemImageName: "sun.and.horizon")
  }

}
