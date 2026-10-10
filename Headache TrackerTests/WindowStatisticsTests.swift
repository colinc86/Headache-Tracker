//
//  WindowStatisticsTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the clock-window statistics calculator and prospective accuracy.
final class WindowStatisticsTests: XCTestCase {

  private let count = WindowStatisticsCalculator.bucketCount

  /// Buckets with a value in every hour: 0, 1, 2, … oldest first.
  private var ramp: [Double?] {
    return (0 ..< count).map({ Double($0) })
  }

  func testStatisticsOverFullRamp() throws {
    let statistics = try XCTUnwrap(WindowStatisticsCalculator.statistics(hourlyBuckets: ramp, aggregate: .discreteAverage))
    // Last 24 buckets are 48…71, mean 59.5; current is 71.
    XCTAssertEqual(try XCTUnwrap(statistics.mean24h), 59.5, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(statistics.delta24h), 71.0 - 59.5, accuracy: 1e-12)
    // Last 6 buckets are 66…71, mean 68.5.
    XCTAssertEqual(try XCTUnwrap(statistics.delta6h), 71.0 - 68.5, accuracy: 1e-12)
    // Last 48 buckets are 24…71 → range 47; all 72 → 71.
    XCTAssertEqual(try XCTUnwrap(statistics.range48h), 47.0, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(statistics.range72h), 71.0, accuracy: 1e-12)
    XCTAssertFalse(statistics.isEmpty)
  }

  func testCumulativeSumSkipsPartialCurrentHour() throws {
    let statistics = try XCTUnwrap(WindowStatisticsCalculator.statistics(hourlyBuckets: ramp, aggregate: .cumulativeSum))
    // Current is the newest *complete* bucket, 70.
    XCTAssertEqual(try XCTUnwrap(statistics.delta24h), 70.0 - 59.5, accuracy: 1e-12)
  }

  func testGapsInsideWindowsAreIgnored() throws {
    var buckets = ramp
    for index in stride(from: 0, to: count, by: 2) {
      buckets[index] = nil
    }
    let statistics = try XCTUnwrap(WindowStatisticsCalculator.statistics(hourlyBuckets: buckets, aggregate: .discreteAverage))
    // Odd values 49…71 in the last 24: mean 60.
    XCTAssertEqual(try XCTUnwrap(statistics.mean24h), 60.0, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(statistics.range48h), 71.0 - 25.0, accuracy: 1e-12)
  }

  func testDegenerateBuckets() throws {
    XCTAssertNil(WindowStatisticsCalculator.statistics(hourlyBuckets: [Double?](repeating: nil, count: count), aggregate: .discreteAverage))
    XCTAssertNil(WindowStatisticsCalculator.statistics(hourlyBuckets: [1.0, 2.0], aggregate: .discreteAverage))

    // A single bucket: a mean but no range (needs two values).
    var single = [Double?](repeating: nil, count: count)
    single[count - 1] = 5.0
    let statistics = try XCTUnwrap(WindowStatisticsCalculator.statistics(hourlyBuckets: single, aggregate: .mostRecent))
    XCTAssertEqual(statistics.mean24h, 5.0)
    XCTAssertEqual(statistics.delta24h, 0.0)
    XCTAssertNil(statistics.range48h)
    XCTAssertNil(statistics.range72h)

    // Only old data: no current value in the 24h window means no delta.
    var old = [Double?](repeating: nil, count: count)
    old[0] = 3.0
    old[1] = 4.0
    let stale = try XCTUnwrap(WindowStatisticsCalculator.statistics(hourlyBuckets: old, aggregate: .discreteAverage))
    XCTAssertNil(stale.mean24h)
    XCTAssertNil(stale.delta24h)
    XCTAssertEqual(stale.range72h, 1.0)
  }

  func testBucketsAlignToHourGrid() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 14, minute: 37)))
    let anchor = WindowStatisticsCalculator.anchor(for: end, calendar: calendar)
    XCTAssertEqual(calendar.component(.minute, from: anchor), 0)
    XCTAssertEqual(calendar.component(.hour, from: anchor), 14)

    var series = [Date: Double]()
    series[anchor] = 10.0                                   // the current hour
    series[anchor.addingTimeInterval(-3600.0)] = 9.0        // the previous hour
    series[anchor.addingTimeInterval(-71.0 * 3600.0)] = 1.0 // the oldest bucket
    series[anchor.addingTimeInterval(-72.0 * 3600.0)] = 99.0 // just outside

    let buckets = WindowStatisticsCalculator.buckets(from: series, endingAt: end, calendar: calendar)
    XCTAssertEqual(buckets.count, count)
    XCTAssertEqual(buckets[count - 1], 10.0)
    XCTAssertEqual(buckets[count - 2], 9.0)
    XCTAssertEqual(buckets[0], 1.0)
    XCTAssertFalse(buckets.contains(99.0))
  }

  func testHourlySeriesAggregation() throws {
    let hour = WindowStatisticsCalculator.anchor(for: Date(timeIntervalSince1970: 1_700_000_000))
    let samples = [
      (date: hour.addingTimeInterval(60.0), value: 2.0),
      (date: hour.addingTimeInterval(1800.0), value: 4.0),
      (date: hour.addingTimeInterval(3000.0), value: 6.0),
    ]
    XCTAssertEqual(WindowStatisticsCalculator.hourlySeries(from: samples, aggregate: .discreteAverage)[hour], 4.0)
    XCTAssertEqual(WindowStatisticsCalculator.hourlySeries(from: samples, aggregate: .mostRecent)[hour], 6.0)
    XCTAssertEqual(WindowStatisticsCalculator.hourlySeries(from: samples, aggregate: .cumulativeSum)[hour], 12.0)
  }

  func testWindowStatisticsRoundTripsThroughJSON() throws {
    let statistics = WindowStatistics(mean24h: 1.0, delta24h: nil, range48h: 3.0, range72h: 4.0, delta6h: -0.5)
    let data = try JSONEncoder().encode(statistics)
    XCTAssertEqual(try JSONDecoder().decode(WindowStatistics.self, from: data), statistics)
    XCTAssertTrue(WindowStatistics().isEmpty)
  }

  // MARK: Prospective accuracy

  func testProspectiveSummaryAndWindows() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    var points = [EvaluationPoint]()
    for day in 0 ..< 30 {
      for hour in stride(from: 0, to: 24, by: 6) {
        let date = start.addingTimeInterval(TimeInterval(day * 86400 + hour * 3600))
        let outcome = day % 5 == 0
        // Right on most days, wrong on day 7.
        let probability = (outcome != (day == 7)) ? 0.8 : 0.2
        points.append(EvaluationPoint(date: date, probability: probability, outcome: outcome))
      }
    }

    let summary = ProspectiveAccuracy.summary(points)
    XCTAssertEqual(summary.count, 120)
    XCTAssertEqual(try XCTUnwrap(summary.accuracy), 116.0 / 120.0, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(summary.baseRateAccuracy), 96.0 / 120.0, accuracy: 1e-12)
    XCTAssertNotNil(summary.brier)
    XCTAssertNotNil(summary.auc)

    let windows = ProspectiveAccuracy.rollingWindows(points, window: 7.0 * 86400.0, step: 86400.0)
    XCTAssertFalse(windows.isEmpty)
    XCTAssertEqual(windows, windows.sorted(by: { $0.date < $1.date }))
    for window in windows {
      XCTAssertGreaterThanOrEqual(window.count, ProspectiveAccuracy.minimumWindowCount)
      XCTAssertGreaterThanOrEqual(window.accuracy, 0.0)
      XCTAssertLessThanOrEqual(window.accuracy, 1.0)
    }
    // The window ending right after day 7 dips below the rest.
    let dipped = try XCTUnwrap(windows.first(where: { $0.date > start.addingTimeInterval(8.0 * 86400.0) }))
    XCTAssertLessThan(dipped.accuracy, 1.0)

    XCTAssertEqual(ProspectiveAccuracy.summary([]).count, 0)
    XCTAssertTrue(ProspectiveAccuracy.rollingWindows([]).isEmpty)
  }

}
