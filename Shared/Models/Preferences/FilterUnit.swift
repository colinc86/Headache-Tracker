//
//  FilterUnit.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/30/22.
//

import Foundation

enum FilterUnit: String, RawRepresentable {
  case day
  case week
  case month
  case year
  
  /// The range to use with the filter count picker.
  var filterCountRange: Range<Int> {
    switch self {
    case .day: return 1 ..< 8
    case .week: return 1 ..< 32
    case .month: return 1 ..< 13
    case .year: return 1 ..< 11
    }
  }
  
  /// The date before now with the number of `count` units of self
  /// before the current date.
  func dateBeforeNow(withCount count: Int) -> Date {
    var interval: TimeInterval = 0.0
    switch self {
    case .day:
      interval = TimeInterval(count) * 86400.0
    case .week:
      interval = TimeInterval(count) * 604800.0
    case .month:
      interval = TimeInterval(count) * 2678400.0
    case .year:
      interval = TimeInterval(count) * 31536000.0
    }
    return Date().addingTimeInterval(-interval)
  }
}
