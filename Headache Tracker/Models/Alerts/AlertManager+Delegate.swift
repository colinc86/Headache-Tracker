//
//  AlertManager+Delegate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation
import UserNotifications

/// The app-side notification delegate: foreground presentation, action
/// handling, and tap routing. Lives in the app target — the widget never
/// receives notification callbacks.
class AlertDelegate: NSObject, UNUserNotificationCenterDelegate {

  /// Notification category identifiers — derived from `HeadacheAlertRequest`
  /// (the single source of truth) so registration here can't drift from the
  /// identifiers the requests actually carry.
  enum Category {
    static let checkIn = HeadacheAlertRequest.Category.checkIn
    static let risk = HeadacheAlertRequest.Category.risk
    static let elevatedRisk = HeadacheAlertRequest.Category.elevatedRisk
    static let morningBrief = HeadacheAlertRequest.Category.morningBrief
  }

  /// Notification action identifiers.
  enum Action {
    static let resolve = "RESOLVE"
    static let logNow = "LOG_NOW"
  }

  /// The app's headache manager, for background actions.
  weak var headacheManager: HeadacheManager?

  /// The app's router, for tap routing.
  weak var router: Router?

  // MARK: Public methods

  /// Registers the notification categories and their actions.
  func registerCategories(with center: UNUserNotificationCenter) {
    let resolve = UNNotificationAction(identifier: Action.resolve, title: "Resolve", options: [.authenticationRequired])
    let logNow = UNNotificationAction(identifier: Action.logNow, title: "Log Now", options: [.foreground])

    center.setNotificationCategories([
      UNNotificationCategory(identifier: Category.checkIn, actions: [resolve, logNow], intentIdentifiers: []),
      UNNotificationCategory(identifier: Category.risk, actions: [logNow], intentIdentifiers: []),
      UNNotificationCategory(identifier: Category.elevatedRisk, actions: [logNow], intentIdentifiers: []),
      UNNotificationCategory(identifier: Category.morningBrief, actions: [], intentIdentifiers: [])
    ])
  }

  // MARK: UNUserNotificationCenterDelegate

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    return [.banner, .list, .sound]
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    // Background resolve from the check-in notification. Mirror the in-app
    // resolve path: cancel the pending check-in and end the Live Activity.
    if response.actionIdentifier == Action.resolve {
      do {
        try await headacheManager?.resolve()
        center.removePendingNotificationRequests(withIdentifiers: [HeadacheAlertRequest.checkInRequestIdentifier])
        if let headacheManager = headacheManager {
          await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)
        }
      }
      catch {
        logError("Error resolving from notification action: \(error)")
      }
      return
    }

    // Everything else routes into the app (default tap or LOG_NOW).
    await MainActor.run {
      router?.routeToTrack()
    }
  }

}
