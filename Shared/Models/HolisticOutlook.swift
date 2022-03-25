//
//  HolisticOutlook.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import Foundation

enum HolisticOutlook {
  
  case noHeadache
  
  case possibleHeadache(onset: Date)
  
  case headache(severity: Headache.Severity, end: Date)
  
  var title: String {
    switch self {
    case .noHeadache: return "No Headache"
    case .possibleHeadache: return "Possible Headache"
    case .headache: return "Headache"
    }
  }
  
  init(outlook: Outlook, onset: Date, duration: TimeInterval, severity: Headache.Severity) {
    switch outlook {
    case .noHeadache:
      self = .noHeadache
    case .possibleHeadache:
      let onsetInterval = onset.timeIntervalSince(Date())
      if onsetInterval > 0.0 && onsetInterval < 86400.0 {
        self = .possibleHeadache(onset: onset)
      }
      else {
        self = .noHeadache
      }
    case .headache:
      if severity != .notPresent {
        self = .headache(severity: severity, end: Date(timeIntervalSinceNow: duration))
      }
      else {
        self = .noHeadache
      }
    }
  }
  
}
