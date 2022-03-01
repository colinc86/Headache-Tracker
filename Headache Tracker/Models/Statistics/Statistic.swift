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
  let signal: [(Double, Date)]
  
  /// The mean's trend.
  let meanTrend: Trend
  
  /// The signal's max.
  let max: Double
  
  /// The earliest date plotted by the series.
  let earliestDate: Date?
  
  /// The number of elements to graph.
  var count: Int {
    guard let earliestDate = earliestDate ?? signal.first?.1 else {
      return 0
    }
    
    return Calendar.current.numberOfDaysBetween(earliestDate, and: Date())
  }
  
  /// The mean value's description.
  var meanDescription: String {
    guard !signal.isEmpty else { return "" }
    return description(for: meanTrend.valueB)
  }
  
  /// The max value's description.
  var maxDescription: String {
    guard !signal.isEmpty else { return "" }
    return description(for: max)
  }
  
  // MARK: Initializers
  
  /// Initializes a statistic.
  ///
  /// - Parameters:
  ///   - earliestDate: The earliest date to graph.
  ///   - signal: The signal.
  ///   - dates: The signal's dates.
  init(earliestDate: Date?, signal: [Double], dates: [Date]) {
    self.earliestDate = earliestDate
    self.signal = [(Double, Date)](zip(signal, dates))
    
    if signal.isEmpty {
      self.max = 0.0
      self.meanTrend = .steady(valueA: 0.0, valueB: 0.0)
    }
    else {
      self.max = Surge.max(signal)
      self.meanTrend = Statistic.meanTrend(for: self.signal, earliestDate: earliestDate)
    }
  }
  
  // MARK: Overridable methods
  
  func description(for value: Double) -> String {
    return "\(value)"
  }
}

extension Statistic {
  
  /// Calculates the mean trend for the given signal and earliest date.
  /// - Parameters:
  ///   - signal: The signal.
  ///   - earliestDate: The earliest date of the signal.
  /// - Returns: A trend.
  private static func meanTrend(for signal: [(Double, Date)],  earliestDate: Date?) -> Trend {
    if let earliestDate = earliestDate {
      let interval = Date().timeIntervalSince(earliestDate)
      let halfDate = earliestDate.addingTimeInterval(interval / 2.0)
      let firstHalfSignal = signal.filter({ $0.1 < halfDate })
      let secondHalfSignal = signal.filter({ $0.1 >= halfDate })
      
      var firstHalfMean = 0.0
      if !firstHalfSignal.isEmpty {
        firstHalfMean = Surge.mean(firstHalfSignal.map({ $0.0 }))
      }
      
      var secondHalfMean = 0.0
      if !secondHalfSignal.isEmpty {
        secondHalfMean = Surge.mean(secondHalfSignal.map({ $0.0 }))
      }
      
      var actualMean = 0.0
      if !signal.isEmpty {
        actualMean = Surge.mean(signal.map({ $0.0 }))
      }
      
      return Trend(firstHalfMean, secondHalfMean, actualMean, 0.2)
    }
    return .steady(valueA: 0.0, valueB: 0.0)
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
    return SeverityRange(lowerBound: lowerSeverity, upperBound: upperSeverity).description
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
