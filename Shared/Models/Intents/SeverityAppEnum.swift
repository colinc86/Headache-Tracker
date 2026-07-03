//
//  SeverityAppEnum.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import AppIntents
import Foundation

/// The severity levels exposed to the intents system.
enum SeverityAppEnum: String, AppEnum {

  case notPresent
  case unspecified
  case mild
  case moderate
  case severe

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Severity")

  static var caseDisplayRepresentations: [SeverityAppEnum: DisplayRepresentation] = [
    .notPresent: "Not Present",
    .unspecified: "Unspecified",
    .mild: "Mild",
    .moderate: "Moderate",
    .severe: "Severe"
  ]

  /// The corresponding headache severity.
  var headacheSeverity: Headache.Severity {
    switch self {
    case .notPresent: return .notPresent
    case .unspecified: return .unspecified
    case .mild: return .mild
    case .moderate: return .moderate
    case .severe: return .severe
    }
  }

  /// Initializes from a headache severity.
  init(_ severity: Headache.Severity) {
    switch severity {
    case .notPresent: self = .notPresent
    case .unspecified: self = .unspecified
    case .mild: self = .mild
    case .moderate: self = .moderate
    case .severe: self = .severe
    @unknown default: self = .unspecified
    }
  }

}
