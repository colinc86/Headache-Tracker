//
//  SceneDelegate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/2/22.
//

import Foundation
import SwiftUI

class SceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
  
  /// The desired severity from an external URL scheme call.
  @Published var desiredSeverity: Headache.Severity?

  /// The app's router, for widget deep links that land on a tab. UIKit
  /// instantiates the scene delegate, so the router is looked up rather
  /// than injected.
  @MainActor private var router: Router? {
    return (UIApplication.shared.delegate as? AppDelegate)?.router
  }
  
  func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    guard let url = contexts.first?.url else {
      logDebug("No url.")
      return
    }
    handle(url)
  }

  /// Parses a `myheadache://severity?rawValue=…` deep link and stages the
  /// requested severity for confirmation. Called from `openURLContexts` (warm
  /// delivery) and SwiftUI's `.onOpenURL` (which also covers a cold launch,
  /// where the URL arrives via the scene's connection options instead).
  func handle(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      logWarning("Unable to open URL \(url.absoluteString)")
      return
    }
    
    // Check the scheme
    guard let scheme = components.scheme, scheme == Constants.URLSchemes.scheme else {
      logWarning("Bad scheme \(components.scheme ?? "")")
      return
    }
    
    // Route widget taps straight to a tab.
    switch components.host {
    case Constants.URLSchemes.outlookHost:
      Task { @MainActor [weak self] in self?.router?.routeToTrack() }
      return
    case Constants.URLSchemes.signalsHost:
      Task { @MainActor [weak self] in self?.router?.routeToProfile(.signals) }
      return
    case Constants.URLSchemes.insightsHost:
      Task { @MainActor [weak self] in self?.router?.routeToProfile(.insights) }
      return
    default:
      break
    }

    // Check the host
    guard let host = components.host, host == Constants.URLSchemes.severityHost else {
      logWarning("Bad host \(components.host ?? "")")
      return
    }
    
    // Get the severity string
    guard let severityString = components.queryItems?.filter({ $0.name == Constants.URLSchemes.rawValueQuery }).first?.value else {
      logWarning("Unable to get severity string.")
      return
    }
    
    // Convert to an integer
    guard let severityRawValue = Int(severityString) else {
      logWarning("Unable to convert to raw value \(severityString).")
      return
    }
    
    // Convert to a severity
    guard let severity = Headache.Severity(rawValue: severityRawValue) else {
      logWarning("Unable to get severity from raw value \(severityRawValue).")
      return
    }
    
    // Set the desired severity
    DispatchQueue.main.async { [weak self] in
      self?.desiredSeverity = severity
    }
  }
  
}
