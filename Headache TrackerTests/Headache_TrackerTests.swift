//
//  Headache_TrackerTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
import DataController
import XCTest
@testable import Headache_Tracker

class Headache_TrackerTests: XCTestCase {

  /// An in-memory data controller rebuilt for each test.
  private var dataController: DataController!

  private var context: NSManagedObjectContext {
    return dataController.container.viewContext
  }

  override func setUpWithError() throws {
    dataController = DataController(containerName: "Headache_Tracker", inMemory: true)
  }

  override func tearDownWithError() throws {
    dataController = nil
  }

  // MARK: Helpers

  private let baseDate = Date(timeIntervalSince1970: 1_000_000)

  private func makeHeadache(severity: Headache.Severity = .mild, start: Date? = nil, end: Date? = nil) -> Headache {
    return Headache(context: context, severity: severity, classification: .primary, type: .tension, start: start ?? baseDate, end: end)
  }

  // MARK: Headache interval invariants

  func testNewHeadacheIsUnresolvedWithOpenSeverity() {
    let headache = makeHeadache()

    XCTAssertFalse(headache.resolved)
    XCTAssertEqual(headache.severitiesArray.count, 1)
    XCTAssertNil(headache.severitiesArray.last?.endTime)
    XCTAssertNotNil(headache.identifier)
    XCTAssertNotNil(headache.severitiesArray.first?.identifier)
  }

  func testCreatingWithEndResolvesImmediately() {
    let headache = makeHeadache(start: baseDate, end: baseDate.addingTimeInterval(3600))

    XCTAssertTrue(headache.resolved)
    XCTAssertEqual(headache.endTime, baseDate.addingTimeInterval(3600))
    XCTAssertNil(headache.currentState)
  }

  func testAddSeverityClosesPreviousInterval() {
    let headache = makeHeadache(severity: .mild)
    let changeDate = baseDate.addingTimeInterval(600)

    let updates = headache.addSeverity(.severe, start: changeDate)

    XCTAssertEqual(headache.severitiesArray.count, 2)
    XCTAssertEqual(headache.severitiesArray.first?.endTime, changeDate)
    XCTAssertNil(headache.severitiesArray.last?.endTime)
    XCTAssertFalse(headache.resolved)
    XCTAssertNotNil(updates.createdSeverityIdentifier)
    XCTAssertEqual(updates.updatedSeverityIdentifier, headache.severitiesArray.first?.identifier)
  }

  func testAddingSameSeverityIsANoOp() {
    let headache = makeHeadache(severity: .mild)

    let updates = headache.addSeverity(.mild, start: baseDate.addingTimeInterval(600))

    XCTAssertEqual(headache.severitiesArray.count, 1)
    XCTAssertNil(updates.createdSeverityIdentifier)
  }

  func testResolveClosesLastSeverityAndSetsResolved() {
    let headache = makeHeadache(severity: .moderate)
    let endDate = baseDate.addingTimeInterval(7200)

    _ = headache.resolve(end: endDate)

    XCTAssertTrue(headache.resolved)
    XCTAssertEqual(headache.severitiesArray.last?.endTime, endDate)
    XCTAssertNil(headache.pendingEndTime)
    XCTAssertNil(headache.currentState)
  }

  func testReorganizeChainsIntervals() {
    let headache = makeHeadache(severity: .mild)
    headache.addSeverity(.moderate, start: baseDate.addingTimeInterval(100))
    headache.addSeverity(.severe, start: baseDate.addingTimeInterval(300))

    // Move the middle severity and reorganize
    headache.severitiesArray[1].startTime = baseDate.addingTimeInterval(200)
    headache.reorganize()

    let severities = headache.severitiesArray
    XCTAssertEqual(severities[0].endTime, severities[1].startTime)
    XCTAssertEqual(severities[1].endTime, severities[2].startTime)
    XCTAssertEqual(headache.createdAt, severities[0].startTime)
  }

  func testReorganizeClampsNegativeLastInterval() {
    // A resolved headache whose last severity ends up with an end time that
    // precedes its start time, as an edit could produce.
    let headache = makeHeadache(severity: .mild, start: baseDate, end: baseDate.addingTimeInterval(100))
    headache.addSeverity(.severe, duration: 100.0)

    let last = headache.severitiesArray.last
    last?.startTime = baseDate.addingTimeInterval(400)
    last?.endTime = baseDate.addingTimeInterval(300)

    headache.reorganize()

    if let lastStart = last?.startTime, let lastEnd = last?.endTime {
      XCTAssertGreaterThanOrEqual(lastEnd, lastStart)
    }
    else {
      XCTFail("Expected a closed last severity")
    }
  }

  func testAverageSeverityIsDurationWeighted() {
    // Mild (2) for 100 seconds, severe (4) for 300 seconds.
    let headache = makeHeadache(severity: .mild)
    headache.addSeverity(.severe, start: baseDate.addingTimeInterval(100))
    _ = headache.resolve(end: baseDate.addingTimeInterval(400))

    XCTAssertEqual(headache.averageSeverity, 3.5, accuracy: 0.0001)

    // The midrange of the same headache is 3.0 — the mislabeled statistic
    // the duration-weighted mean replaced.
    XCTAssertEqual(headache.severityRange.midpoint, 3.0, accuracy: 0.0001)
  }

  // MARK: Trend

  func testTrendEqualValuesAreSteady() {
    XCTAssertTrue(Trend(5.0, 5.0).isSteady)
    XCTAssertTrue(Trend(0.0, 0.0).isSteady)
  }

  func testTrendFromZeroIsRising() {
    let trend = Trend(0.0, 5.0)
    XCTAssertFalse(trend.isSteady)
    if case .falling = trend {
      XCTFail("Expected rising")
    }
  }

  func testTrendDirections() {
    if case .rising = Trend(1.0, 2.0) {} else { XCTFail("Expected rising") }
    if case .falling = Trend(2.0, 1.0) {} else { XCTFail("Expected falling") }
    if case .falling = Trend(5.0, 0.0) {} else { XCTFail("Expected falling") }
  }

  func testTrendTolerance() {
    XCTAssertTrue(Trend(100.0, 101.0, nil, 0.05).isSteady)
    XCTAssertFalse(Trend(100.0, 110.0, nil, 0.05).isSteady)
  }

  // MARK: Headache rates

  func testHeadacheRatesWithNoHeadachesIsZero() {
    let rates = HeadacheStatistics.headacheRates([])
    XCTAssertEqual(rates.0, 0.0)
    XCTAssertEqual(rates.1, 0.0)
    XCTAssertEqual(rates.2, 0.0)
  }

  func testHeadacheRatesWithSingleHeadacheIsZero() {
    let headache = makeHeadache()
    let rates = HeadacheStatistics.headacheRates([headache])

    XCTAssertEqual(rates.0, 0.0)
    XCTAssertFalse(rates.0.isInfinite)
    XCTAssertFalse(rates.0.isNaN)
  }

  func testHeadacheRatesAreOrderIndependent() {
    let first = makeHeadache(start: baseDate)
    let second = makeHeadache(severity: .severe, start: baseDate.addingTimeInterval(604800), end: baseDate.addingTimeInterval(608400))

    let sorted = HeadacheStatistics.headacheRates([first, second])
    let unsorted = HeadacheStatistics.headacheRates([second, first])

    // Two headaches one week apart: two per week.
    XCTAssertEqual(sorted.2, 2.0, accuracy: 0.0001)
    XCTAssertEqual(unsorted.2, sorted.2, accuracy: 0.0001)
    XCTAssertGreaterThan(unsorted.2, 0.0)
  }

  // MARK: Label derivation

  func testDeriveLabelsFromEpisodes() throws {
    let onset = baseDate.addingTimeInterval(100_000)
    let headache = makeHeadache(severity: .severe, start: onset, end: onset.addingTimeInterval(10_000))
    let episodes = [try XCTUnwrap(headache.episode)]

    let far = TrainingData(context: context)
    far.timestamp = onset.addingTimeInterval(-172_800) // 48 h before onset

    let near = TrainingData(context: context)
    near.timestamp = onset.addingTimeInterval(-72_000) // 20 h before onset

    let during = TrainingData(context: context)
    during.timestamp = onset.addingTimeInterval(5_000)

    let after = TrainingData(context: context)
    after.timestamp = onset.addingTimeInterval(20_000)

    [far, near, during, after].deriveLabels(from: episodes)

    XCTAssertEqual(far.outlook, .noHeadache)
    XCTAssertEqual(near.outlook, .possibleHeadache)
    XCTAssertEqual(near.timeIntervalUntilNextHeadacheStart ?? 0, 72_000, accuracy: 0.001)
    XCTAssertEqual(during.outlook, .headache)
    XCTAssertEqual(during.derivedSeverity, .severe)
    XCTAssertEqual(during.timeIntervalUntilNextHeadacheEnd ?? 0, 5_000, accuracy: 0.001)
    XCTAssertEqual(after.outlook, .noHeadache)
    XCTAssertEqual(after.derivedSeverity, .notPresent)
    XCTAssertNil(after.timeIntervalUntilNextHeadacheStart)
  }

  func testDeriveLabelsUsesRollingWindowNotCalendarDay() throws {
    // A sample one hour before a headache that starts just after midnight.
    // The old calendar-day logic labeled this .noHeadache.
    let midnight = Calendar.current.startOfDay(for: baseDate.addingTimeInterval(86_400))
    let onset = midnight.addingTimeInterval(1_800) // 00:30
    let headache = makeHeadache(severity: .mild, start: onset, end: onset.addingTimeInterval(3_600))
    let episodes = [try XCTUnwrap(headache.episode)]

    let sample = TrainingData(context: context)
    sample.timestamp = midnight.addingTimeInterval(-1_800) // 23:30 the day before

    [sample].deriveLabels(from: episodes)

    XCTAssertEqual(sample.outlook, .possibleHeadache)
  }

  // MARK: Training data trimming

  func testTrimmedTrainingDataBalancesClasses() {
    let headache = makeHeadache(severity: .mild)
    guard let severity = headache.severitiesArray.first else {
      XCTFail("Expected a severity")
      return
    }

    // 3 headache rows and 20 not-present rows.
    var trainingData = [TrainingData]()
    for i in 0 ..< 23 {
      let data = TrainingData(context: context)
      data.timestamp = baseDate.addingTimeInterval(Double(i) * 3600.0)
      if i < 3 {
        severity.addToTrainingData(data)
      }
      trainingData.append(data)
    }

    let trimmed = HeadacheManager.trimmedTrainingData(trainingData)
    let notPresent = trimmed.filter({ $0.severity == nil || $0.severity?.severity == .notPresent })
    let present = trimmed.filter({ $0.severity != nil && $0.severity?.severity != .notPresent })

    // With fewer than 50 present rows, not-present rows are trimmed to at
    // most twice the present count.
    XCTAssertEqual(present.count, 3)
    XCTAssertLessThanOrEqual(notPresent.count, 6)
  }

}
