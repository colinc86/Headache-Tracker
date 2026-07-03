//
//  AlertManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import Foundation
import UserNotifications

protocol AlertRequest {
  var identifier: String { get }
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
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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
  /// - Parameter options: The options to request authorization to.
  /// - Returns: The current authorization status.
  @discardableResult
  @MainActor func setup(options: UNAuthorizationOptions) async throws -> UNAuthorizationStatus {
    let settings = await checkNotificationSettings()
    
    // Only continue if our authorization status is unknown or we have option changes
    guard settings.authorizationStatus == .notDetermined else {
      return settings.authorizationStatus
    }
    
    // Request authorization from the user
    try await requestAuthorization(options: options)
    
    // There was no error, so return the new authorization status
    return (await checkNotificationSettings()).authorizationStatus
  }
  
  /// Schedules a check-in alert for the given headache after the given
  /// interval, replacing any pending check-in.
  ///
  /// - Parameters:
  ///   - headacheIdentifier: The headache's identifier.
  ///   - interval: The interval from now at which the alert fires.
  @MainActor func scheduleCheckInAlert(headacheIdentifier: UUID, interval: TimeInterval) async throws {
    // Cancel any pending check-in notification (scoped, so the repeating
    // evening exposure reminder survives)
    let request = HeadacheAlertRequest.checkIn(headacheIdentifier: headacheIdentifier)
    removePendingRequests(withIdentifiers: [request.identifier])

    let futureDate = Date(timeIntervalSinceNow: interval)
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)

    logDebug("Scheduling check-in alert at \(futureDate).")
    try await presentAlert(
      with: request,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
      badgeNumber: 0)
  }

  /// Removes pending requests with the given identifiers.
  ///
  /// - Parameter identifiers: The notification request identifiers.
  func removePendingRequests(withIdentifiers identifiers: [String]) {
    logDebug("Removing pending requests: \(identifiers).")
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
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
  @MainActor func presentAlert(with request: AlertRequest, trigger: UNNotificationTrigger? = nil, badgeNumber: Int = 0) async throws {
    guard await checkAuthorization() else {
      throw AlertError.notAuthorized
    }
    
    try await self.center.add(request.notificationRequest(trigger: trigger, badgeNumber: badgeNumber))
  }
  
  /// Sets the application's badge number.
  ///
  /// - Parameter number: The badge number to display.
  @MainActor func setApplicationIconBadgeNumber(_ number: Int) async throws {
    guard await checkAuthorization() else {
      throw AlertError.notAuthorized
    }

    try await center.setBadgeCount(number)
  }
  
}

// MARK: Private methods

extension AlertManager {
  
  /// Checks the manager's authorization status.
  ///
  /// - Returns: A boolean indicating if the app is authorized to present alerts.
  @MainActor private func checkAuthorization() async -> Bool {
    let settings = await checkNotificationSettings()
    return settings.authorizationStatus != .notDetermined && settings.authorizationStatus != .denied
  }
  
  /// Checks the current notification settings.
  ///
  /// - Returns: The user notification settings.
  @MainActor private func checkNotificationSettings() async -> UNNotificationSettings {
    let notificationSettings = await center.notificationSettings()
    
    // Publish the authorization status
    DispatchQueue.main.async { [weak self] in
      self?.authorizationStatus = notificationSettings.authorizationStatus
    }
    
    return notificationSettings
  }
  
  /// Requests authorization from the user to display alerts.
  @discardableResult
  @MainActor private func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    return try await center.requestAuthorization(options: options)
  }
  
}
