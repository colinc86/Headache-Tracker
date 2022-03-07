//
//  Bundle+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import Foundation

extension Bundle {
  
  /// A human-readable version and bundle string.
  var humanReadableVersionString: String {
    return "\(versionString ?? "N/A") (\(buildString ?? "N/A"))"
  }
  
  /// The application's version string.
  var versionString: String? {
    return infoDictionary?["CFBundleShortVersionString"] as? String
  }
  
  /// The application's build string.
  var buildString: String? {
    return infoDictionary?["CFBundleVersion"] as? String
  }
  
}
