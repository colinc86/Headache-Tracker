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
  
}
