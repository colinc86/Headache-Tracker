//
//  HKCategoryValueSeverity+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import HealthKit

extension HKCategoryValueSeverity {
  
  /// The severity's title suitable for a user.
  public var title: String {
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
  
}
