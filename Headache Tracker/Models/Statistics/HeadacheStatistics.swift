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
  
  // MARK: Initializers
  
  /// Initializes a seet of headache statistics.
  ///
  /// - Parameter headaches: The headaches.
  init(headaches: [Headache]) {
    var peaks = [Double](repeating: 0.0, count: headaches.count)
    var averages = [Double](repeating: 0.0, count: headaches.count)
    var onsets = [Double](repeating: 0.0, count: headaches.count)
    var durations = [Double](repeating: 0.0, count: headaches.count)
    
    // Do one loop through the headaches and convert
    for i in 0 ..< headaches.count {
      peaks[i] = Double(headaches[i].severityRange.upperBound.orderingValue)
      averages[i] = Double(headaches[i].severityRange.average)
      durations[i] = headaches[i].duration
      if let startTime = headaches[i].startTime {
        onsets[i] = Calendar.current.timeIntervalSinceMidnight(startTime)
      }
    }
    
    // Create statistics
    self.peaks = SeverityStatistic(signal: peaks)
    self.averages = SeverityStatistic(signal: averages)
    self.onsets = OnsetStatistic(signal: onsets)
    self.durations = DurationStatistic(signal: durations)
  }
  
}
