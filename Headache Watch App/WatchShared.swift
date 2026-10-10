//
//  WatchShared.swift
//  Headache Watch App
//
//  Created by Colin Campbell on 7/18/26.
//
//  Self-contained watch-side mirror of the small slice of shared state the
//  watch needs. It reads the app-group `UserDefaults` the phone already
//  writes (`Preferences.Shared`), so the watch never compiles the iOS model
//  layer (Core Data, HealthKit, CreateML) — none of which exists on watchOS.
//

import Foundation
import SwiftUI

enum WatchShared {

  /// The app group the phone shares the current forecast/severity through.
  static let appGroup = "group.com.cnc.Headache-Tracker.contents"

  /// The literal defaults keys the phone writes (see `Preferences.Shared`).
  static let riskKey = "settings.shared.currentRisk"
  static let severityKey = "settings.shared.currentSeverity"

  static var defaults: UserDefaults? {
    return UserDefaults(suiteName: appGroup)
  }

  /// A severity level, mirroring `HKCategoryValueSeverity`'s raw values so the
  /// phone can map the wrist tap straight back to `Headache.Severity`.
  enum Severity: Int, CaseIterable, Identifiable {
    case unspecified = 0
    case notPresent = 1
    case mild = 2
    case moderate = 3
    case severe = 4

    var id: Int { rawValue }

    var title: String {
      switch self {
      case .unspecified: return "Logged"
      case .notPresent: return "Resolved"
      case .mild: return "Mild"
      case .moderate: return "Moderate"
      case .severe: return "Severe"
      }
    }

    var color: Color {
      switch self {
      case .unspecified: return .gray
      case .notPresent: return .green
      case .mild: return .yellow
      case .moderate: return .orange
      case .severe: return .red
      }
    }
  }

  /// A minimal decode of the stored forecast — the phone's `RiskPrediction`
  /// blob has more fields, but JSON decoding ignores the extras.
  struct Risk: Decodable {
    let probability: Double
    let shortProbability: Double?
  }

  /// The current forecast, or nil when none is stored or no model exists yet
  /// (the phone writes a sentinel negative probability for "no forecast").
  static func currentRisk() -> Risk? {
    guard let data = defaults?.data(forKey: riskKey),
          let risk = try? JSONDecoder().decode(Risk.self, from: data),
          risk.probability >= 0 else {
      return nil
    }
    return risk
  }

  /// The active headache's severity, or nil when no headache is in progress.
  static func activeSeverity() -> Severity? {
    guard let raw = defaults?.object(forKey: severityKey) as? Int,
          let severity = Severity(rawValue: raw),
          severity != .notPresent else {
      return nil
    }
    return severity
  }

  /// A coarse tier for the forecast probability.
  enum Tier {
    case low, elevated, high

    init(probability: Double) {
      if probability >= 0.60 { self = .high }
      else if probability >= 0.30 { self = .elevated }
      else { self = .low }
    }

    var title: String {
      switch self {
      case .low: return "Low Risk"
      case .elevated: return "Elevated Risk"
      case .high: return "High Risk"
      }
    }

    var color: Color {
      switch self {
      case .low: return .mint
      case .elevated: return .orange
      case .high: return .pink
      }
    }
  }

  /// The forecast probability formatted as a percent.
  static func percent(_ probability: Double) -> String {
    return "\(Int((probability * 100.0).rounded()))%"
  }

}
