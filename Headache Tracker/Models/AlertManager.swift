//
//  AlertManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import Foundation
import UserNotifications
import Logger
import SwiftUI
import UIKit

protocol AlertRequest {
  var title: String { get }
  var body: String { get }
  var userInfo: [AnyHashable: Any]? { get }
  var categoryIdentifier: String { get }
  var sound: UNNotificationSound { get }
}

extension AlertRequest {
  
  /// Creates a notification request from the receiver.
  ///
  /// - Parameters:
  ///   - trigger: The request's trigger condition.
  ///   - badgeNumber: The badge number to set with the alert.
  /// - Returns: A new notification request.
  public func notificationRequest(trigger: UNNotificationTrigger?, badgeNumber: Int) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.userInfo = userInfo ?? [:]
    content.categoryIdentifier = categoryIdentifier
    content.sound = sound
    content.badge = NSNumber(integerLiteral: badgeNumber)
    return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
  }
  
}

/// Manages the presentation of alerts to the user.
class AlertManager: NSObject, ObservableObject {
  
  // MARK: Types
  
  /// An alert error.
  enum AlertError: DescribableError {
    case notAuthorized
    
    var description: String {
      switch self {
      case .notAuthorized:
        return "The application is not authorized to send alerts."
      }
    }
  }
  
  // MARK: Public properties
  
  /// The manager's authorization status.
  @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
  
  // MARK: Private properties
  
  /// The manager's notification center.
  private let center: UNUserNotificationCenter
  
  // MARK: Initializers
  
  /// Initializes a new alert manager.
  /// - Parameter center: The user notification center.
  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }
  
}

// MARK: Public methods

extension AlertManager {
  
  /// Sets up the alert manager.
  ///
  /// - Parameters:
  ///   - options: The options to request authorization to.
  ///   - completion: Called after the status is determined.
  func setup(options: UNAuthorizationOptions, completion: ((UNAuthorizationStatus, Error?) -> Void)?) {
    // Get the initial authorization status
    checkNotificationSettings { [weak self] settings in
      guard let self = self else { completion?(.notDetermined, nil); return }
      
      // Only continue if our authorization status is unknown or we have option changes
      guard settings.authorizationStatus == .notDetermined else {
        completion?(settings.authorizationStatus, nil)
        return
      }
      
      // Request authorization from the user
      self.requestAuthorization(options: options) { granted, error in
        if let error = error {
          // If we have an error, return the current status
          completion?(settings.authorizationStatus, error)
          return
        }
        
        // There was no error, so return the new authorization status
        self.checkNotificationSettings(completion: { newSettings in
          completion?(newSettings.authorizationStatus, nil)
          return
        })
      }
    }
  }
  
  /// Removes all requests from the center.
  func removeRequests(pending: Bool = true, delivered: Bool = true) {    
    if pending {
      logDebug("Removing pending requests.")
      center.removeAllPendingNotificationRequests()
    }
    
    if delivered {
      logDebug("Removing delivered requests.")
      center.removeAllDeliveredNotifications()
    }
  }
  
  /// Presents an alert to the user.
  /// - Parameters:
  ///   - request:  The alert to present to the user.
  ///   - badgeNumber: The application badge number.
  ///   - completion: The completion to call.
  func presentAlert(with request: AlertRequest, trigger: UNNotificationTrigger? = nil, badgeNumber: Int = 0, completion: ((Error?) -> Void)? = nil) {
    checkAuthorization { [weak self] authorized in
      guard let self = self else { completion?(nil); return }
      
      guard authorized else {
        completion?(AlertError.notAuthorized)
        return
      }
      
      DispatchQueue.main.async {
        self.center.add(request.notificationRequest(trigger: trigger, badgeNumber: badgeNumber), withCompletionHandler: completion)
      }
    }
  }
  
  /// Sets the application's badge number.
  ///
  /// - Parameter number: The badge number to display.
  func setApplicationIconBadgeNumber(_ number: Int, completion: ((Error?) -> Void)? = nil) {
    checkAuthorization { authorized in
      guard authorized else {
        completion?(AlertError.notAuthorized)
        return
      }
      
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = number
      }
    }
  }
  
}

// MARK: Private methods

extension AlertManager {
  
  /// Checks the manager's authorization status.
  ///
  /// - Parameter completion: Called with a boolean to signify whether or not the
  ///   manager is authorized.
  private func checkAuthorization(completion: @escaping (Bool) -> Void) {
    checkNotificationSettings { settings in
      completion(settings.authorizationStatus != .notDetermined && settings.authorizationStatus != .denied)
    }
  }
  
  /// Checks the current notification settings.
  ///
  /// - Parameter completion: Completion handler containing the settings.
  private func checkNotificationSettings(completion: @escaping (UNNotificationSettings) -> Void) {
    center.getNotificationSettings { [weak self] notificationSettings in
      // Publish the authorization status
      DispatchQueue.main.async {
        self?.authorizationStatus = notificationSettings.authorizationStatus
      }
      
      // Call the completion block
      completion(notificationSettings)
    }
  }
  
  /// Requests authorization from the user to display alerts.
  private func requestAuthorization(options: UNAuthorizationOptions, completion: @escaping (Bool, Error?) -> Void) {
    center.requestAuthorization(options: options) { granted, error in
      completion(granted, error)
    }
  }
  
}
