//
//  SeverityInterval.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import Foundation
import HealthKit

/// Pairs a severity value with a date interval.
struct SeverityInterval {
  let severity: HKCategoryValueSeverity
  let interval: DateInterval
}
