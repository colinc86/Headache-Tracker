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
  
  func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    guard let url = contexts.first?.url else {
      logDebug("No url.")
      return
    }
    
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      logWarning("Unable to open URL \(url.absoluteString)")
      return
    }
    
    // Check the scheme
    guard let scheme = components.scheme, scheme == Constants.URLSchemes.scheme else {
      logWarning("Bad scheme \(components.scheme ?? "")")
      return
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
