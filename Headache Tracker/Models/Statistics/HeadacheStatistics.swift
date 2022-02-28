//
//  HeadacheStatistics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/17/22.
//

import Foundation
import HealthKit
import Surge

struct HeadacheStatistics {
  
  /// The highest severity of each headache.
  let peaks: SeverityStatistic
  
  /// The average severity of each headache.
  let averages: SeverityStatistic
  
  /// The onset of each headache.
  let onsets: OnsetStatistic
  
  /// The duration of each headache.
  let durations: DurationStatistic
  
  let headachesPerYear: Double
  let headachesPerMonth: Double
  let headachesPerWeek: Double
  
  // MARK: Initializers
  
  /// Initializes a set of headache statistics.
  ///
  /// - Parameter headaches: The headaches.
  init(headaches: [Headache], earliestDate: Date?) {
    let now = Date()
    var dates = [Date](repeating: now, count: headaches.count)
    var peaks = [Double](repeating: 0.0, count: headaches.count)
    var averages = [Double](repeating: 0.0, count: headaches.count)
    var onsets = [Double](repeating: 0.0, count: headaches.count)
    var durations = [Double](repeating: 0.0, count: headaches.count)
    
    // Do one loop through the headaches and convert
    for i in 0 ..< headaches.count {
      dates[i] = headaches[i].createdAt ?? dates[i]
      peaks[i] = Double(headaches[i].severityRange.upperBound.orderingValue)
      averages[i] = Double(headaches[i].severityRange.average)
      durations[i] = headaches[i].duration
      if let startTime = headaches[i].startTime {
        onsets[i] = Calendar.current.timeIntervalSinceMidnight(startTime)
      }
    }
    
    // Create statistics
    self.peaks = SeverityStatistic(earliestDate: earliestDate, signal: peaks, dates: dates)
    self.averages = SeverityStatistic(earliestDate: earliestDate, signal: averages, dates: dates)
    self.onsets = OnsetStatistic(earliestDate: earliestDate, signal: onsets, dates: dates)
    self.durations = DurationStatistic(earliestDate: earliestDate, signal: durations, dates: dates)
    
    // Rates
    if let firstHeadacheDate = headaches.first?.startTime, let lastHeadacheDate = headaches.last?.startTime {
      let interval = lastHeadacheDate.timeIntervalSince(firstHeadacheDate)
      let years = interval / 31536000.0
      let months = interval / 2678400.0
      let weeks = interval / 604800.0
      let headacheCount = Double(headaches.count)
      
      self.headachesPerYear = headacheCount / years
      self.headachesPerMonth = headacheCount / months
      self.headachesPerWeek = headacheCount / weeks
    }
    else {
      self.headachesPerYear = 0.0
      self.headachesPerMonth = 0.0
      self.headachesPerWeek = 0.0
    }
  }
  
}
