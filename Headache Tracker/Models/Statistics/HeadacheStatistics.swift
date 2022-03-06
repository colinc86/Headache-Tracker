//
//  HeadacheStatistics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/17/22.
//

import Foundation
import HealthKit
import Surge
import SwiftUI

struct HeadacheStatistics {
  
  /// The highest severity of each headache.
  let peaks: SeverityStatistic
  
  /// The average severity of each headache.
  let averages: SeverityStatistic
  
  /// The onset of each headache.
  let onsets: OnsetStatistic
  
  /// The duration of each headache.
  let durations: DurationStatistic
  
  /// The severity ranges of the headaches.
  let severityRanges: [(SeverityRange, Date)]
  
  /// The number of headaches per year.
  let headachesPerYear: Double
  let headachesPerYearTrend: Trend
  
  /// The number of headaches per month.
  let headachesPerMonth: Double
  let headachesPerMonthTrend: Trend
  
  /// The number of headaches per week.
  let headachesPerWeek: Double
  let headachesPerWeekTrend: Trend
  
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
    var severities = [SeverityRange](repeating: .empty, count: headaches.count)
    
    // Do one loop through the headaches and convert
    for i in 0 ..< headaches.count {
      dates[i] = headaches[i].createdAt ?? dates[i]
      peaks[i] = Double(headaches[i].severityRange.upperBound.orderingValue)
      averages[i] = Double(headaches[i].severityRange.average)
      durations[i] = headaches[i].duration
      severities[i] = headaches[i].severityRange
      if let startTime = headaches[i].startTime {
        onsets[i] = Calendar.current.timeIntervalSinceMidnight(startTime)
      }
    }
    
    // Create statistics
    self.peaks = SeverityStatistic(earliestDate: earliestDate, signal: peaks, dates: dates)
    self.averages = SeverityStatistic(earliestDate: earliestDate, signal: averages, dates: dates)
    self.onsets = OnsetStatistic(earliestDate: earliestDate, signal: onsets, dates: dates)
    self.durations = DurationStatistic(earliestDate: earliestDate, signal: durations, dates: dates)
    self.severityRanges = [(SeverityRange, Date)](zip(severities, dates))
    
    // Rates and trends
    if let earliestDate = earliestDate {
      let now = Date()
      let totalInterval = now.timeIntervalSince(earliestDate)
      let halfInterval = totalInterval / 2.0
      let halfDate = earliestDate.addingTimeInterval(halfInterval)
      
      let firstHalfHeadaches = headaches.filter({ ($0.startTime ?? now) < halfDate })
      let secondHalfHeadaches = headaches.filter({ ($0.startTime ?? now) >= halfDate })
      
      logDebug("Got \(firstHalfHeadaches.count) first, \(secondHalfHeadaches.count) second")
      
      let firstHalfRates = HeadacheStatistics.headacheRates(firstHalfHeadaches)
      let secondHalfRates = HeadacheStatistics.headacheRates(secondHalfHeadaches)
      let totalRates = HeadacheStatistics.headacheRates(headaches)
      
      logDebug("First half rates: \(firstHalfRates)")
      logDebug("Second half rates: \(secondHalfRates)")
      logDebug("Total rates: \(totalRates)")
      
      self.headachesPerYear = totalRates.0
      self.headachesPerYearTrend = Trend(firstHalfRates.0, secondHalfRates.0)
      
      self.headachesPerMonth = totalRates.1
      self.headachesPerMonthTrend = Trend(firstHalfRates.1, secondHalfRates.1)
      
      self.headachesPerWeek = totalRates.2
      self.headachesPerWeekTrend = Trend(firstHalfRates.2, secondHalfRates.2)
    }
    else {
      logWarning("Setting to none.")
      self.headachesPerYear = 0.0
      self.headachesPerYearTrend = .steady(valueA: 0.0, valueB: 0.0)
      self.headachesPerMonth = 0.0
      self.headachesPerMonthTrend = .steady(valueA: 0.0, valueB: 0.0)
      self.headachesPerWeek = 0.0
      self.headachesPerWeekTrend = .steady(valueA: 0.0, valueB: 0.0)
    }
  }
  
}

extension HeadacheStatistics {
  
  /// Returns the rates of the headaches in years, months and weeks, in that order.
  ///
  /// - Parameter headaches: The headaches.
  static func headacheRates(_ headaches: [Headache]) -> (Double, Double, Double) {
    logDebug("Get rates with \(headaches.count) headaches.")
    if let firstHeadacheDate = headaches.first?.createdAt, let lastHeadacheDate = headaches.last?.createdAt {
      logDebug("Got first and last dates \(firstHeadacheDate) \(lastHeadacheDate)")
      let interval = lastHeadacheDate.timeIntervalSince(firstHeadacheDate)
      let years = interval / 31536000.0
      let months = interval / 2678400.0
      let weeks = interval / 604800.0
      let headacheCount = Double(headaches.count)
      return (headacheCount / years, headacheCount / months, headacheCount / weeks)
    }
    return (0.0, 0.0, 0.0)
  }
  
}
