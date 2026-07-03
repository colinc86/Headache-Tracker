//
//  HeadacheAlertRequest.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import Foundation
import UserNotifications

enum HeadacheAlertRequest: AlertRequest {
  
  static let headacheIdentifierUserInfoKey = "headacheIdentifier"
  
  case checkIn(headacheIdentifier: UUID)
  case risk(probability: Double)
  case outlook(tier: RiskPrediction.RiskTier, probability: Double)
  case exposureCheckIn

  /// Stable identifiers so scheduling replaces prior pending requests of
  /// the same kind, and removal can be scoped instead of nuking everything.
  public var identifier: String {
    switch self {
    case .checkIn: return "headache-check-in"
    case .risk: return "risk"
    case .outlook: return "outlook"
    case .exposureCheckIn: return "exposure-check-in"
    }
  }

  public var title: String {
    switch self {
    case .checkIn:
      return "How's your headache?"
    case .risk:
      return "High Headache Risk"
    case .outlook:
      return "Your Daily Headache Outlook"
    case .exposureCheckIn:
      return "Daily Check-In"
    }
  }
  
  public var body: String {
    switch self {
    case .checkIn(_):
      return "Tap here to give an update on your headache."
    case .risk(let probability):
      return "Your headache risk is high: \(Int((probability * 100.0).rounded()))% in the next 24 hours."
    case .outlook(let tier, let probability):
      switch tier {
      case .low:
        return "Your daily outlook is good — low headache risk today."
      case .elevated, .high:
        return "Heads up: \(Int((probability * 100.0).rounded()))% chance of a headache in the next 24 hours."
      }
    case .exposureCheckIn:
      return "Log today's exposures — caffeine, alcohol, stress, and more — to sharpen your insights."
    }
  }
  
  public var userInfo: [AnyHashable : Any]? {
    switch self {
    case .checkIn(let headacheIdentifier):
      return [HeadacheAlertRequest.headacheIdentifierUserInfoKey: headacheIdentifier.uuidString]
    default: return nil
    }
  }
  
  var categoryIdentifier: String {
    return "alert"
  }
  
  var sound: UNNotificationSound {
    return .default
  }
  
}
