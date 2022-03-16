//
//  Numeric+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/17/22.
//

import Foundation

extension Double {
  
  /// Rounds the receiver to the nearest multiple of `nearest`.
  ///
  /// - Parameter nearest: The nearest multiple to round to.
  /// - Returns: A rounded value.
  func round(nearest: Double) -> Double {
    let n = 1/nearest
    let numberToRound = self * n
    return numberToRound.rounded() / n
  }
  
  /// Creates a percent format string with the given number of decimal places.
  ///
  /// - Parameter decimalPlaces: The decimal places to create the percent
  ///   with.
  /// - Returns: A string.
  func percentFormat(decimalPlaces: Int = 0) -> String {
    let formatString = "%0.\(decimalPlaces)f%%"
    return String(format: formatString, self * 100.0)
  }
  
}
