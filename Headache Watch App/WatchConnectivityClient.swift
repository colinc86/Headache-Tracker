//
//  WatchConnectivityClient.swift
//  Headache Watch App
//
//  Created by Colin Campbell on 7/18/26.
//

import Foundation
import WatchConnectivity
import WidgetKit

/// The watch side of quick-logging: sends a chosen severity to the phone,
/// which performs the real `changeSeverity` flow (Core Data + HealthKit +
/// training + Live Activity) that only exists in the phone process. It also
/// receives the phone's pushed forecast/severity and mirrors it into the
/// watch's app-group container so `WatchShared` (and the complication) can
/// read it — app groups never sync across devices, so this push is the only
/// path that populates them.
final class WatchConnectivityClient: NSObject, WCSessionDelegate {

  /// The message key carrying the chosen severity's raw value.
  static let severityMessageKey = "severity"

  /// Posted after a fresh forecast/severity context is applied, so the home
  /// view can re-read `WatchShared`.
  static let contextDidChange = Notification.Name("WatchConnectivityClient.contextDidChange")

  /// The shared client.
  static let shared = WatchConnectivityClient()

  private override init() {
    super.init()
  }

  /// Activates the session if the platform supports it.
  func activate() {
    guard WCSession.isSupported() else {
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// Sends the chosen severity to the phone. Falls back to a queued transfer
  /// when the phone isn't immediately reachable.
  ///
  /// - Parameter severity: The severity to log.
  func log(_ severity: WatchShared.Severity) {
    guard WCSession.isSupported() else {
      return
    }
    let session = WCSession.default
    let payload = [Self.severityMessageKey: severity.rawValue]

    if session.activationState == .activated && session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { _ in
        // Delivery failed while reachable — queue it instead.
        session.transferUserInfo(payload)
      }
    }
    else {
      session.transferUserInfo(payload)
    }
  }

  /// Mirrors the phone's pushed forecast + active severity into the watch's
  /// own app-group container and nudges the UI and complication to re-read.
  /// `updateApplicationContext` replaces the whole context each time, so an
  /// absent key means "clear it" (e.g. a resolved headache drops the severity).
  static func apply(_ context: [String: Any]) {
    guard let defaults = WatchShared.defaults else {
      return
    }

    if let riskData = context[WatchShared.riskKey] as? Data {
      defaults.set(riskData, forKey: WatchShared.riskKey)
    }
    else {
      defaults.removeObject(forKey: WatchShared.riskKey)
    }

    if let severity = context[WatchShared.severityKey] as? Int {
      defaults.set(severity, forKey: WatchShared.severityKey)
    }
    else {
      defaults.removeObject(forKey: WatchShared.severityKey)
    }

    // UI/complication refresh on the main queue; the delegate callbacks can
    // arrive on a background thread.
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: contextDidChange, object: nil)
      WidgetCenter.shared.reloadTimelines(ofKind: "RiskComplication")
    }
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    // Apply whatever the phone last pushed, even when it isn't reachable now:
    // WCSession persists the most recent application context across launches.
    if activationState == .activated {
      Self.apply(session.receivedApplicationContext)
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    Self.apply(applicationContext)
  }

}
