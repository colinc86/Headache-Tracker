//
//  WindowStatistics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// Trailing fixed-clock-window statistics for one signal.
///
/// The model otherwise sees a single snapshot per row. These give it the
/// signal's recent level, its deviation from that level, and its volatility.
/// Every statistic derives from hourly clock buckets, never from the spacing
/// of stored rows: rows are logged when the app is used, and usage tracks
/// headaches, so anything computed over row spacing would learn engagement
/// instead of physiology.
///
/// Absent ≠ 0: a nil statistic means no buckets existed for that window.
struct WindowStatistics: Codable, Equatable {

  /// The mean over the last 24 hours.
  var mean24h: Double?

  /// The current value minus `mean24h`.
  var delta24h: Double?

  /// The peak-to-trough range over the last 48 hours.
  var range48h: Double?

  /// The peak-to-trough range over the last 72 hours.
  var range72h: Double?

  /// The current value minus the mean over the last 6 hours.
  var delta6h: Double?

  /// Whether no statistic is present.
  var isEmpty: Bool {
    return mean24h == nil && delta24h == nil && range48h == nil && range72h == nil && delta6h == nil
  }

  init(mean24h: Double? = nil, delta24h: Double? = nil, range48h: Double? = nil, range72h: Double? = nil, delta6h: Double? = nil) {
    self.mean24h = mean24h
    self.delta24h = delta24h
    self.range48h = range48h
    self.range72h = range72h
    self.delta6h = delta6h
  }

}

/// How a metric's hourly buckets were aggregated, which decides what
/// "current" means.
enum WindowAggregate {

  /// Each bucket is the hour's average (heart rate, temperature, …).
  case discreteAverage

  /// Each bucket is the hour's newest reading (resting heart rate, …).
  case mostRecent

  /// Each bucket is the hour's total (steps). The partial current hour
  /// under-counts, so "current" is the newest complete bucket.
  case cumulativeSum

}

/// Computes `WindowStatistics` from hourly buckets.
enum WindowStatisticsCalculator {

  /// The number of hourly buckets a window read covers.
  static let bucketCount = 72

  /// The length of one bucket.
  static let bucketLength: TimeInterval = 3600.0

  /// The buckets the 24-hour statistics cover.
  static let mean24hBucketCount = 24

  /// The buckets the 6-hour delta covers.
  static let mean6hBucketCount = 6

  /// The buckets the 48-hour range covers.
  static let range48hBucketCount = 48

  /// The anchor for buckets ending at a date: the date floored to the hour.
  /// Bucket `i` covers `[anchor − (bucketCount − i)h, anchor − (bucketCount − 1 − i)h)`,
  /// so the last bucket is the (partial) current hour.
  ///
  /// - Parameters:
  ///   - date: The end of the window.
  ///   - calendar: The calendar.
  /// - Returns: The anchor.
  static func anchor(for date: Date, calendar: Calendar = .current) -> Date {
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    return calendar.date(from: components) ?? date
  }

  /// The statistics over hourly buckets.
  ///
  /// - Parameters:
  ///   - hourlyBuckets: Exactly `bucketCount` entries, oldest first; nil where
  ///     the hour had no samples.
  ///   - aggregate: How the buckets were aggregated.
  /// - Returns: The statistics, or nil when every bucket is nil.
  static func statistics(hourlyBuckets: [Double?], aggregate: WindowAggregate) -> WindowStatistics? {
    guard hourlyBuckets.count == bucketCount, hourlyBuckets.contains(where: { $0 != nil }) else {
      return nil
    }

    func mean(lastBuckets count: Int) -> Double? {
      let values = hourlyBuckets.suffix(count).compactMap({ $0 })
      guard !values.isEmpty else {
        return nil
      }
      return values.reduce(0.0, +) / Double(values.count)
    }

    func range(lastBuckets count: Int) -> Double? {
      let values = hourlyBuckets.suffix(count).compactMap({ $0 })
      guard values.count >= 2, let minimum = values.min(), let maximum = values.max() else {
        return nil
      }
      return maximum - minimum
    }

    // "Current" is the newest bucket with data; a cumulative bucket for the
    // partial current hour is skipped because it under-counts.
    let searchable = aggregate == .cumulativeSum ? hourlyBuckets.dropLast() : hourlyBuckets[...]
    let current = searchable.last(where: { $0 != nil }) ?? nil

    let mean24h = mean(lastBuckets: mean24hBucketCount)
    let mean6h = mean(lastBuckets: mean6hBucketCount)

    var statistics = WindowStatistics()
    statistics.mean24h = mean24h
    statistics.range48h = range(lastBuckets: range48hBucketCount)
    statistics.range72h = range(lastBuckets: bucketCount)
    if let current = current {
      if let mean24h = mean24h {
        statistics.delta24h = current - mean24h
      }
      if let mean6h = mean6h {
        statistics.delta6h = current - mean6h
      }
    }
    return statistics
  }

  /// Slices a sparse hour-keyed series into the buckets ending at a date.
  ///
  /// - Parameters:
  ///   - series: Values keyed by the start of their hour.
  ///   - date: The end of the window.
  ///   - calendar: The calendar.
  /// - Returns: `bucketCount` entries, oldest first.
  static func buckets(from series: [Date: Double], endingAt date: Date, calendar: Calendar = .current) -> [Double?] {
    let anchor = anchor(for: date, calendar: calendar)
    return (0 ..< bucketCount).map { index in
      let hoursBack = bucketCount - 1 - index
      let bucketStart = anchor.addingTimeInterval(-TimeInterval(hoursBack) * bucketLength)
      return series[bucketStart]
    }
  }

  /// Buckets timestamped samples by the start of their hour, aggregating each
  /// hour with the given rule. Keys are hour starts on the same grid
  /// `buckets(from:endingAt:)` reads.
  ///
  /// - Parameters:
  ///   - samples: Dated values.
  ///   - aggregate: How to combine the values within an hour.
  ///   - calendar: The calendar.
  /// - Returns: The hour-keyed series.
  static func hourlySeries(from samples: [(date: Date, value: Double)], aggregate: WindowAggregate, calendar: Calendar = .current) -> [Date: Double] {
    var grouped = [Date: [(Date, Double)]]()
    for sample in samples {
      grouped[anchor(for: sample.date, calendar: calendar), default: []].append((sample.date, sample.value))
    }

    var series = [Date: Double]()
    for (hour, values) in grouped {
      switch aggregate {
      case .discreteAverage:
        series[hour] = values.map({ $0.1 }).reduce(0.0, +) / Double(values.count)
      case .mostRecent:
        series[hour] = values.max(by: { $0.0 < $1.0 })?.1
      case .cumulativeSum:
        series[hour] = values.map({ $0.1 }).reduce(0.0, +)
      }
    }
    return series
  }

}
