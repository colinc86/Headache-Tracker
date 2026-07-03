//
//  HKCategoryValueSeverity+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import HealthKit
import SwiftUI

extension HKCategoryValueSeverity: Codable, @retroactive RawRepresentable {
  
  // MARK: Types
  
  /// A range of severities.
  typealias Range = ClosedRange<HKCategoryValueSeverity>
  
  /// Pairs a severity range with a date.
  struct DatedRange {
    
    /// An empty dated range.
    static let empty = DatedRange(range: .empty, date: .distantPast)
    
    /// The severity range.
    let range: Range
    
    /// The range's date.
    let date: Date
  }
  
  /// Pairs a severity value with a date interval.
  struct Interval {

    /// The severity.
    let severity: HKCategoryValueSeverity

    /// The severity's date interval.
    let interval: DateInterval

    /// The identifier of the severity state the interval represents. Used to
    /// scope HealthKit samples to their owning severity.
    let identifier: UUID?

    /// Creates a new severity interval.
    ///
    /// - Parameters:
    ///   - severity: The severity.
    ///   - start: The severity's start time.
    ///   - end: The severity's end time.
    ///   - identifier: The identifier of the owning severity state.
    init(_ severity: HKCategoryValueSeverity, start: Date, end: Date, identifier: UUID? = nil) {
      self.severity = severity
      self.interval = DateInterval(start: start, end: end)
      self.identifier = identifier
    }
  }
  
  // MARK: Properties
  
  /// The severity's title suitable for a user.
  var title: String {
    switch self {
    case .notPresent: return "Not Present"
    case .mild: return "Mild"
    case .moderate: return "Moderate"
    case .severe: return "Severe"
    case .unspecified: return "Present"
    default: return "Unknown"
    }
  }
  
  /// The value's integer value representation.
  var orderingValue: Int {
    switch self {
    case .notPresent: return 0
    case .unspecified: return 1
    case .mild: return 2
    case .moderate: return 3
    case .severe: return 4
    default: return -1
    }
  }
  
  // MARK: Initializers
  
  /// Creates a severity from the value obtained from the
  /// `orderingValue` property.
  ///
  /// - Parameter orderingValue: The severity's ordering value.
  init?(orderingValue: Int) {
    switch orderingValue {
    case 0: self = .notPresent
    case 1: self = .unspecified
    case 2: self = .mild
    case 3: self = .moderate
    case 4: self = .severe
    default: return nil
    }
  }
  
  /// Creates a severity from the value obtained from the
  /// `title` property.
  ///
  /// - Parameter title: The severity's title.
  init?(title: String) {
    switch title {
    case HKCategoryValueSeverity.notPresent.title: self = .notPresent
    case HKCategoryValueSeverity.unspecified.title: self = .unspecified
    case HKCategoryValueSeverity.mild.title: self = .mild
    case HKCategoryValueSeverity.moderate.title: self = .moderate
    case HKCategoryValueSeverity.severe.title: self = .severe
    default: return nil
    }
  }
  
}

// MARK: Comparable protocol

extension HKCategoryValueSeverity: @retroactive Comparable {
  public static func < (lhs: HKCategoryValueSeverity, rhs: HKCategoryValueSeverity) -> Bool {
    return lhs.orderingValue < rhs.orderingValue
  }
}

// MARK: Range methods

extension HKCategoryValueSeverity.Range {
  
  /// An empty range.
  static var empty: Self {
    HKCategoryValueSeverity.Range(lowerBound: .notPresent, upperBound: .notPresent)
  }
  
  /// The range's description built from titles.
  var description: String {
    if lowerBound == upperBound {
      return lowerBound.title
    }
    return "\(lowerBound.title) - \(upperBound.title)"
  }
  
  /// The midpoint of the range's bounds.
  ///
  /// This is a midrange, not an average of the severity progression; use
  /// `Headache.averageSeverity` for a duration-weighted mean.
  var midpoint: Double {
    return Double(lowerBound.orderingValue + upperBound.orderingValue) / 2.0
  }
  
  /// Creates a severity range.
  ///
  /// - Parameters:
  ///   - lowerBound: The range's lower bound.
  ///   - upperBound: The range's upper bound.
  init(lowerBound: HKCategoryValueSeverity, upperBound: HKCategoryValueSeverity) {
    self.init(uncheckedBounds: (lowerBound, upperBound))
  }
  
}
