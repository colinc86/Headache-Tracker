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
  case prediction(severity: Headache.Severity)
  case outlook(outlook: Outlook, onset: Date?)
  case exposureCheckIn

  /// Stable identifiers so scheduling replaces prior pending requests of
  /// the same kind, and removal can be scoped instead of nuking everything.
  public var identifier: String {
    switch self {
    case .checkIn: return "headache-check-in"
    case .prediction: return "prediction"
    case .outlook: return "outlook"
    case .exposureCheckIn: return "exposure-check-in"
    }
  }

  public var title: String {
    switch self {
    case .checkIn:
      return "How's your headache?"
    case .prediction:
      return "New Headache Prediction"
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
    case .prediction(let severity):
      return "You may have a \(severity.title.lowercased()) headache. Tap here to give an update."
    case .outlook(let outlook, let onset):
      if outlook == .headache {
        if let onset = onset {
          return "Your daily headache outlook contains a possible headache at \(onset.formattedTime())."
        }
        else {
          return "Your daily headache outlook contains a possible headache."
        }
      }
      else {
        return "Your daily headache outlook is good with no headaches!"
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
