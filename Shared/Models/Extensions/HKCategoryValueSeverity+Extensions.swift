//
//  HKCategoryValueSeverity+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import HealthKit
import SwiftUI

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
  
  /// The image to use when displaying the severity.
  var image: Image? {
    switch self {
    case .unspecified: return Image(Constants.AssetKeys.headacheSeverityPresent)
    case .mild: return Image(Constants.AssetKeys.headacheSeverityMild)
    case .moderate: return Image(Constants.AssetKeys.headacheSeverityModerate)
    case .severe: return Image(Constants.AssetKeys.headacheSeveritySevere)
    default: return nil
    }
  }
  
  /// The color to use when drawing the value in the user interface.
  var uiColor: Color {
    switch self {
    case .notPresent: return Color.headacheSeverityNotPresent
    case .unspecified: return Color.headacheSeverityPresent
    case .mild: return Color.headacheSeverityMild
    case .moderate: return Color.headacheSeverityModerate
    case .severe: return Color.headacheSeveritySevere
    default: return Color.headacheSeverityNotPresent
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
