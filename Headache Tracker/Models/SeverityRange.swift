//
//  SeverityRange.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import Foundation
import HealthKit

/// Pairs two severity values together as a closed range.
struct SeverityRange: CustomStringConvertible, Equatable {
  
  /// The range's lower bound.
  let lowerBound: HKCategoryValueSeverity
  
  /// The range's upper bound.
  let upperBound: HKCategoryValueSeverity
  
  var description: String {
    if lowerBound == upperBound {
      return lowerBound.title
    }
    return "\(lowerBound.title) - \(upperBound.title)"
  }
  
  /// The range's average.
  var average: Double {
    return Double(lowerBound.orderingValue + upperBound.orderingValue) / 2.0
  }
  
  // MARK: Initializers
  
  init(lowerBound: HKCategoryValueSeverity, upperBound: HKCategoryValueSeverity) {
    self.lowerBound = lowerBound
    self.upperBound = upperBound
  }
  
  // MARK: Public methods
  
  func contains(_ severity: HKCategoryValueSeverity) -> Bool {
    return lowerBound.orderingValue <= severity.orderingValue && severity.orderingValue <= upperBound.orderingValue
  }
  
  // MARK: Static methods
  
  static func == (lhs: SeverityRange, rhs: SeverityRange) -> Bool {
    return lhs.lowerBound.orderingValue == rhs.lowerBound.orderingValue &&
    lhs.upperBound.orderingValue == rhs.upperBound.orderingValue
  }
}
