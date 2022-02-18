//
//  Statistic.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/17/22.
//

import Foundation
import HealthKit
import Surge

/// A headache statistic.
class Statistic {
  
  /// The statistic's signal.
  let signal: [Double]
  
  /// The signal's mean.
  let mean: Double
  
  /// The signal's max.
  let max: Double
  
  /// The mean value's description.
  var meanDescription: String {
    return description(for: mean)
  }
  
  var maxDescription: String {
    return description(for: max)
  }
  
  // MARK: Initializers
  
  /// Initializes a statistic.
  ///
  /// - Parameter signal: The signal.
  init(signal: [Double]) {
    self.signal = signal
    self.mean = Surge.mean(signal)
    self.max = Surge.max(signal)
  }
  
  // MARK: Overridable methods
  
  func description(for value: Double) -> String {
    return "\(value)"
  }
}

class SeverityStatistic: Statistic {
  override func description(for value: Double) -> String {
    let roundedPeakSeverity = value.round(nearest: 0.5)
    let lowerBound = Int(floor(roundedPeakSeverity))
    let upperBound = Int(ceil(roundedPeakSeverity))
    guard let lowerSeverity = HKCategoryValueSeverity(orderingValue: lowerBound),
          let upperSeverity = HKCategoryValueSeverity(orderingValue: upperBound) else {
            return ""
          }
    return HealthKitManager.SeverityRange(lowerBound: lowerSeverity, upperBound: upperSeverity).description
  }
}

class OnsetStatistic: Statistic {
  override func description(for value: Double) -> String {
    return Formatters.timeFormatter.string(from: Calendar.current
                                            .startOfDay(for: Date())
                                            .addingTimeInterval(value))
  }
}

class DurationStatistic: Statistic {
  override func description(for value: Double) -> String {
    return Formatters.dateComponentsFormatter.string(from: value) ?? ""
  }
}
