//
//  Formatters.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import Foundation

struct Formatters {
  
  /// The date components formatter for displaying time intervals.
  static let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.minute, .hour, .day]
    formatter.maximumUnitCount = 2
    return formatter
  }()
  
  /// The date formatter to use when displaying times from dates.
  static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
  }()
  
}
