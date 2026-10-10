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
  
  /// The date `count` units of self before the current date.
  ///
  /// Uses calendar arithmetic so the window matches real months and years and
  /// stays correct across DST. A flat 31-day "month"/365-day "year" made "Last
  /// 12 months" span *more* than "Last 1 year" and drifted the boundaries off
  /// the calendar. Falls back to a flat interval only if the calendar can't
  /// resolve the date (it effectively always can).
  func dateBeforeNow(withCount count: Int) -> Date {
    let calendar = Calendar.current
    let now = Date()

    let component: Calendar.Component
    let secondsPerUnit: TimeInterval
    switch self {
    case .day:   component = .day;        secondsPerUnit = 86400.0
    case .week:  component = .weekOfYear;  secondsPerUnit = 604800.0
    case .month: component = .month;       secondsPerUnit = 2678400.0
    case .year:  component = .year;        secondsPerUnit = 31536000.0
    }

    return calendar.date(byAdding: component, value: -count, to: now)
      ?? now.addingTimeInterval(-TimeInterval(count) * secondsPerUnit)
  }
}
