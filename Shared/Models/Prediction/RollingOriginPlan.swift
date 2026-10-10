//
//  RollingOriginPlan.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// A forward-chained ("rolling-origin") evaluation plan over a chronologically
/// sorted series of inputs.
///
/// Each fold trains on everything that came before its test block, with a
/// 24-hour embargo: a training row's 24h-ahead label is only knowable once
/// that day has passed, so rows within a horizon of the test block would
/// carry the test period's own onsets into training. The old single 80/20
/// split lacked that gap. Pure; simulator-safe.
struct RollingOriginPlan: Equatable {

  /// One forward-chained fold.
  struct Fold: Equatable {

    /// The fold's index, oldest first.
    let index: Int

    /// The rows to train on (a prefix of the series).
    let trainingIndices: Range<Int>

    /// The rows to score.
    let testIndices: Range<Int>

    /// The start of the test block.
    let testStart: Date

    /// The end of the test block (exclusive).
    let testEnd: Date

  }

  /// The default number of folds.
  static let defaultFoldCount = 5

  /// The number of folds used when fewer than `smallSeriesCount` rows exist.
  static let smallSeriesFoldCount = 3

  /// Below this many rows the fold count drops to `smallSeriesFoldCount`.
  static let smallSeriesCount = 150

  /// The fraction of rows reserved as warm-up before the first test block.
  static let warmUpFraction = 0.4

  /// The gap between a fold's newest training row and its test block.
  static let embargo: TimeInterval = RiskHorizon.standard.window

  /// The folds, oldest first.
  let folds: [Fold]

  /// Builds a plan over sorted dates.
  ///
  /// The warm-up is the first `warmUpFraction` of rows, snapped forward to
  /// the next local midnight. The remaining calendar days are cut into
  /// `foldCount` contiguous blocks of roughly equal row count, each starting
  /// at a local midnight. Folds with no test rows are dropped.
  ///
  /// - Parameters:
  ///   - dates: The row dates, sorted ascending.
  ///   - foldCount: The requested fold count; nil picks by series size.
  ///   - warmUpFraction: The warm-up fraction.
  ///   - calendar: The calendar defining midnight.
  /// - Returns: The plan (possibly with no folds).
  static func make(
    dates: [Date],
    foldCount: Int? = nil,
    warmUpFraction: Double = RollingOriginPlan.warmUpFraction,
    calendar: Calendar = .current
  ) -> RollingOriginPlan {
    guard dates.count >= 2 else {
      return RollingOriginPlan(folds: [])
    }

    let requested = foldCount ?? (dates.count < smallSeriesCount ? smallSeriesFoldCount : defaultFoldCount)
    guard requested > 0 else {
      return RollingOriginPlan(folds: [])
    }

    // The warm-up ends at the first midnight at or after the warm-up row.
    let warmUpIndex = min(max(Int(Double(dates.count) * warmUpFraction), 1), dates.count - 1)
    let warmUpEnd = nextMidnight(atOrAfter: dates[warmUpIndex], calendar: calendar)

    // The candidate rows are those dated at or after the warm-up end,
    // grouped by their local day.
    guard let firstCandidate = dates.firstIndex(where: { $0 >= warmUpEnd }) else {
      return RollingOriginPlan(folds: [])
    }

    var dayStarts = [Date]()
    var dayRowCounts = [Int]()
    for date in dates[firstCandidate...] {
      let day = calendar.startOfDay(for: date)
      if dayStarts.last == day {
        dayRowCounts[dayRowCounts.count - 1] += 1
      }
      else {
        dayStarts.append(day)
        dayRowCounts.append(1)
      }
    }

    // Cut the days into blocks of roughly equal row count.
    let totalRows = dates.count - firstCandidate
    let blockCount = min(requested, dayStarts.count)
    let target = Double(totalRows) / Double(blockCount)
    var blockStartDays = [0]
    var accumulated = 0
    for (dayIndex, count) in dayRowCounts.enumerated() {
      accumulated += count
      if blockStartDays.count < blockCount && Double(accumulated) >= target * Double(blockStartDays.count) && dayIndex + 1 < dayStarts.count {
        blockStartDays.append(dayIndex + 1)
      }
    }

    var folds = [Fold]()
    for (blockIndex, startDay) in blockStartDays.enumerated() {
      let testStart = dayStarts[startDay]
      let testEnd: Date
      if blockIndex + 1 < blockStartDays.count {
        testEnd = dayStarts[blockStartDays[blockIndex + 1]]
      }
      else {
        testEnd = calendar.date(byAdding: .day, value: 1, to: dayStarts[dayStarts.count - 1]) ?? .distantFuture
      }

      let testLower = dates.firstIndex(where: { $0 >= testStart }) ?? dates.count
      let testUpper = dates.firstIndex(where: { $0 >= testEnd }) ?? dates.count
      guard testLower < testUpper else {
        continue
      }

      let cutoff = testStart.addingTimeInterval(-embargo)
      let trainingUpper = dates.firstIndex(where: { $0 > cutoff }) ?? dates.count
      guard trainingUpper > 0 else {
        continue
      }

      folds.append(Fold(
        index: folds.count,
        trainingIndices: 0 ..< trainingUpper,
        testIndices: testLower ..< testUpper,
        testStart: testStart,
        testEnd: testEnd))
    }

    return RollingOriginPlan(folds: folds)
  }

  /// The next local midnight at or after the date.
  private static func nextMidnight(atOrAfter date: Date, calendar: Calendar) -> Date {
    let start = calendar.startOfDay(for: date)
    if start == date {
      return start
    }
    return calendar.date(byAdding: .day, value: 1, to: start) ?? date
  }

}
