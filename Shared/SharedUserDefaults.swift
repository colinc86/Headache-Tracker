//
//  SharedUserDefaults.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/21/22.
//

import Foundation

class SharedUserDefaults {
  
  // MARK: Types
  
  struct Keys {
    static let lastOutlookUpdate = "lastOutlookUpdate"
    static let outlookKey = "outlook"
    static let onset = "onset"
  }
  
  // MARK: Static properties
  
  /// The application's app group identifier.
  static let appGroupIdentifier = "group.com.cnc.Headache-Tracker.contents"
  
  /// The shared standard user defaults.
  static let standard = SharedUserDefaults()
  
  // MARK: Private properties
  
  /// The shared defaults.
  private let defaults = UserDefaults(suiteName: SharedUserDefaults.appGroupIdentifier)
  
  // MARK: Public properties
  
  /// The last time the outlook was updated.
  var lastOutlookUpdate: Date? {
    get {
      return defaults?.value(forKey: Keys.lastOutlookUpdate) as? Date
    }
    
    set {
      defaults?.set(newValue, forKey: Keys.lastOutlookUpdate)
      defaults?.synchronize()
    }
  }
  
  /// The current outlook.
  var outlook: Outlook {
    get {
      if let outlook = defaults?.string(forKey: Keys.outlookKey) {
        return Outlook(rawValue: outlook) ?? .noHeadache
      }
      return .noHeadache
    }
    
    set {
      defaults?.set(newValue.rawValue, forKey: Keys.outlookKey)
      defaults?.synchronize()
    }
  }
  
  /// The current onset.
  var onset: Date? {
    get {
      return defaults?.value(forKey: Keys.onset) as? Date
    }
    
    set {
      defaults?.set(newValue, forKey: Keys.onset)
      defaults?.synchronize()
    }
  }
  
}
