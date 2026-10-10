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

  /// The stable identifier of the pending headache check-in request, for
  /// scoped removal from paths that don't have a request instance.
  static let checkInRequestIdentifier = "headache-check-in"
  
  case checkIn(headacheIdentifier: UUID)
  case risk(probability: Double)
  case elevatedRisk(probability: Double, reasons: [String])
  case morningBrief(tier: RiskPrediction.RiskTier, probability: Double, reasons: [String])

  /// Stable identifiers so scheduling replaces prior pending requests of
  /// the same kind, and removal can be scoped instead of nuking everything.
  public var identifier: String {
    switch self {
    case .checkIn: return HeadacheAlertRequest.checkInRequestIdentifier
    case .risk: return "risk"
    case .elevatedRisk: return "elevated-risk"
    case .morningBrief: return "morning-brief"
    }
  }

  public var title: String {
    switch self {
    case .checkIn:
      return "How's your headache?"
    case .risk:
      return "High Headache Risk"
    case .elevatedRisk:
      return "Risk Climbing"
    case .morningBrief:
      return "Your Morning Brief"
    }
  }

  public var body: String {
    switch self {
    case .checkIn(_):
      return "Tap here to give an update on your headache."
    case .risk(let probability):
      return "Your headache risk is high: \(Int((probability * 100.0).rounded()))% in the next 24 hours."
    case .elevatedRisk(let probability, let reasons):
      // Caring and actionable: lead with the strongest reason, if we have one.
      var body = "Risk is climbing — \(Int((probability * 100.0).rounded()))% in the next 24 hours."
      if let reason = reasons.first {
        body += " \(reason). A little care now can help."
      }
      else {
        body += " A little care now can help."
      }
      return body
    case .morningBrief(let tier, let probability, let reasons):
      var body: String
      switch tier {
      case .low:
        body = "Low headache risk today."
      case .elevated, .high:
        body = "Heads up: \(Int((probability * 100.0).rounded()))% chance of a headache in the next 24 hours."
      }
      if let reason = reasons.first {
        body += " \(reason)."
      }
      return body
    }
  }
  
  public var userInfo: [AnyHashable : Any]? {
    switch self {
    case .checkIn(let headacheIdentifier):
      return [HeadacheAlertRequest.headacheIdentifierUserInfoKey: headacheIdentifier.uuidString]
    default: return nil
    }
  }
  
  /// The notification category identifiers — the single source of truth the
  /// app's `AlertDelegate` derives its registration and routing from, so the
  /// two can't silently drift apart (which would drop a notification's action
  /// buttons with no compile error).
  enum Category {
    static let checkIn = "checkIn"
    static let risk = "risk"
    static let elevatedRisk = "elevatedRisk"
    static let morningBrief = "morningBrief"
  }

  var categoryIdentifier: String {
    switch self {
    case .checkIn: return Category.checkIn
    case .risk: return Category.risk
    case .elevatedRisk: return Category.elevatedRisk
    case .morningBrief: return Category.morningBrief
    }
  }
  
  var sound: UNNotificationSound {
    return .default
  }
  
}
