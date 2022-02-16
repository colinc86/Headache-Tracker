//
//  HeadacheAlertRequest.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import Foundation
import HealthKit
import UserNotifications

enum HeadacheAlertRequest: AlertRequest {
  
  static let headacheIdentifierUserInfoKey = "headacheIdentifier"
  
  case checkIn(headacheIdentifier: UUID)
  case prediction(severity: HKCategoryValueSeverity)
  
  public var title: String {
    switch self {
    case .checkIn:
      return "How's your headache?"
    case .prediction:
      return "New Headache Prediction"
    }
  }
  
  public var body: String {
    switch self {
    case .checkIn(_):
      return "Tap here to give an update on your headache."
    case .prediction(let severity):
      return "You may have a \(severity.title.lowercased()) headache. Tap here to give an update."
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
