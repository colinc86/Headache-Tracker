//
//  Date+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import Foundation

/// Adds conformance to `RawRepresentable` to the `Date` structure.
extension Date: RawRepresentable {
  
  private static let rawFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
  private static var formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = rawFormat
    return formatter
  }()
  
  public var rawValue: String {
    return Date.formatter.string(from: self)
  }
  
  public init?(rawValue: String) {
    if let date = Date.formatter.date(from: rawValue) {
      self = date
    }
    else {
      return nil
    }
  }
  
  /// The relative date string to use.
  func formattedRelative() -> String {
    return Calendar.current.relativeDateDescription(self)
  }
  
  /// The non-relative date string to use.
  func formattedNonRelative() -> String {
    return formattedDate() + " at " + formattedTime()
  }
  
  /// The formatted time to use.
  func formattedTime() -> String {
    return formatted(date: .omitted, time: .shortened)
  }
  
  /// The formatted date to use.
  func formattedDate() -> String {
    return formatted(date: .abbreviated, time: .omitted)
  }
  
}
