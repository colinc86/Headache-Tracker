//
//  Calendar+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/15/22.
//

import Foundation

extension Calendar {
  
  /// Calculates the number of days between the given dates.
  ///
  /// - Parameters:
  ///   - from: The start date.
  ///   - to: The end date.
  /// - Returns: The number of days.
  func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
    return dateComponents(
      [.day],
      from: startOfDay(for: from),
      to: startOfDay(for: to)
    ).day ?? 0
  }
  
  /// Returns the time interval since midnight for the given date.
  ///
  /// - Parameter date: The date.
  /// - Returns: The number of seconds since midnight.
  func timeIntervalSinceMidnight(_ date: Date) -> TimeInterval {
    return date.timeIntervalSince(startOfDay(for: date))
  }
  
  /// Returns the day of the week for the given date.
  ///
  /// - Parameter date: The date.
  /// - Returns: The day of the week.
  func dayOfWeek(_ date: Date) -> Int {
    return component(.weekday, from: date)
  }
  
  /// Returns the date of midnight after the given date.
  ///
  /// - Parameter date: The date.
  /// - Returns: The date that represents midnight after `date`.
  func midnightAfter(_ date: Date) -> Date {
    return startOfDay(for: date.addingTimeInterval(86400.0))
  }
  
  /// A description of the date relative to now.
  ///
  /// - Parameter date: The date to describe.
  /// - Returns: A string.
  func relativeDateDescription(_ date: Date) -> String {
    let timeString = Formatters.timeFormatter.string(from: date)
    let days = numberOfDaysBetween(date, and: Date())
    
    var dayString = ""
    if days == 1 {
      dayString = "Yesterday at "
    }
    else if days > 1 {
      dayString = "\(days) days ago at "
    }
    else if days == -1 {
      dayString = "Tomorrow at "
    }
    else if days < -1 {
      dayString = "In \(days) days at "
    }
    
    return dayString + timeString
  }
  
  
}
