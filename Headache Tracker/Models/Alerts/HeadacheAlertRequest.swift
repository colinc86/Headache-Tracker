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
  
  public var title: String {
    switch self {
    case .checkIn:
      return "How's your headache?"
    }
  }
  
  public var body: String {
    switch self {
    case .checkIn(_):
      return "Tap here to give an update on your headache."
    }
  }
  
  public var userInfo: [AnyHashable : Any]? {
    switch self {
    case .checkIn(let headacheIdentifier):
      return [HeadacheAlertRequest.headacheIdentifierUserInfoKey: headacheIdentifier.uuidString]
    }
  }
  
  var categoryIdentifier: String {
    return "alert"
  }
  
  var sound: UNNotificationSound {
    return .default
  }
  
}
