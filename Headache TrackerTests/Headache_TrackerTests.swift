//
//  Headache_TrackerTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
import DataController
import HealthKit
import SwiftUI
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

  func testFrequencyTrendUsesToleranceForSteady() {
    let now = Date()
    let earliest = now.addingTimeInterval(-40.0 * 86400.0)

    // First half of the window: two headaches 5 days apart (~2.8/week).
    _ = makeHeadache(start: now.addingTimeInterval(-35.0 * 86400.0))
    _ = makeHeadache(start: now.addingTimeInterval(-30.0 * 86400.0))
    // Second half: two headaches 5.5 days apart (~2.55/week) — about a 9%
    // change, inside the 20% tolerance, so the trend should read steady rather
    // than flipping to a falling arrow on noise. With a zero tolerance (the old
    // wiring) the non-equal rates would read falling.
    _ = makeHeadache(start: now.addingTimeInterval(-15.5 * 86400.0))
    _ = makeHeadache(start: now.addingTimeInterval(-10.0 * 86400.0))

    let all = (try? context.fetch(Headache.fetchRequest())) ?? []
    XCTAssertEqual(all.count, 4)
    let stats = HeadacheStatistics(headaches: all, earliestDate: earliest)
    // Guard against a trivially-steady empty result: the data must have flowed
    // through so the rate is real.
    XCTAssertGreaterThan(stats.headachesPerWeek, 0.0)
    XCTAssertTrue(stats.headachesPerWeekTrend.isSteady)
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

  // MARK: Correlation math

  func testPearsonKnownValues() throws {
    let x = [1.0, 2.0, 3.0, 4.0, 5.0]
    XCTAssertEqual(try XCTUnwrap(CorrelationMath.pearson(x, [2.0, 4.0, 6.0, 8.0, 10.0])), 1.0, accuracy: 1e-10)
    XCTAssertEqual(try XCTUnwrap(CorrelationMath.pearson(x, [10.0, 8.0, 6.0, 4.0, 2.0])), -1.0, accuracy: 1e-10)
    XCTAssertNil(CorrelationMath.pearson(x, [3.0, 3.0, 3.0, 3.0, 3.0]), "Constant arrays have no defined correlation")
    XCTAssertNil(CorrelationMath.pearson(x, [1.0, 2.0]), "Mismatched lengths")
  }

  func testRanksAverageTies() {
    XCTAssertEqual(CorrelationMath.ranks([1.0, 2.0, 2.0, 3.0]), [1.0, 2.5, 2.5, 4.0])
    XCTAssertEqual(CorrelationMath.ranks([5.0, 1.0, 3.0]), [3.0, 1.0, 2.0])
  }

  func testSpearmanMonotonicNonlinear() throws {
    let x = (1 ... 20).map(Double.init)
    let y = x.map({ exp($0 / 5.0) })
    XCTAssertEqual(try XCTUnwrap(CorrelationMath.spearman(x, y)), 1.0, accuracy: 1e-10)
  }

  func testPointBiserialSeparatedGroups() throws {
    let x = [1.0, 1.0, 1.0, 5.0, 5.0, 5.0]
    let target = [false, false, false, true, true, true]
    XCTAssertEqual(try XCTUnwrap(CorrelationMath.pointBiserial(x, target)), 1.0, accuracy: 1e-10)
  }

  func testBenjaminiHochberg() {
    let q = CorrelationMath.benjaminiHochberg([0.005, 0.04, 0.04, 0.05])
    XCTAssertEqual(q[0], 0.02, accuracy: 1e-10)
    XCTAssertEqual(q[1], 0.05, accuracy: 1e-10)
    XCTAssertEqual(q[2], 0.05, accuracy: 1e-10)
    XCTAssertEqual(q[3], 0.05, accuracy: 1e-10)
  }

  func testCircularShiftPValueDetectsStrongSignal() {
    let x = (0 ..< 120).map({ sin(Double($0) / 3.0) })
    let p = CorrelationMath.circularShiftPValue(coefficient: 1.0, x: x, y: x)
    XCTAssertLessThan(p, 0.05)
    XCTAssertGreaterThan(p, 0.0)
  }

  // MARK: Correlation engine

  func testEngineFindsPlantedTrigger() {
    // Hourly samples over ~12 days with 10 headache episodes every 30 hours.
    // The planted feature is elevated in the 6 hours before each onset.
    let start = baseDate
    var episodes = [HeadacheEpisode]()
    for k in 1 ... 10 {
      let onset = start.addingTimeInterval(Double(k) * 30.0 * 3600.0)
      episodes.append(HeadacheEpisode(
        start: onset,
        end: onset.addingTimeInterval(2.0 * 3600.0),
        severities: [HeadacheEpisode.SeverityInterval(severity: .moderate, start: onset, end: onset.addingTimeInterval(2.0 * 3600.0))]))
    }

    var samples = [CorrelationSample]()
    for hour in 0 ..< 320 {
      let timestamp = start.addingTimeInterval(Double(hour) * 3600.0)
      let preOnset = episodes.contains(where: { episode in
        episode.start > timestamp && episode.start.timeIntervalSince(timestamp) <= 6.0 * 3600.0
      })
      // Deterministic jitter keeps the arrays non-constant.
      let jitter = Double(hour % 3) * 0.01
      samples.append(CorrelationSample(
        timestamp: timestamp,
        values: [.heartRate: (preOnset ? 5.0 : 1.0) + jitter]))
    }

    let report = CorrelationEngine(samples: samples, episodes: episodes).computeReport()

    let occurrence = report.insights.first(where: { $0.feature == .heartRate && $0.target == .occurrence })
    XCTAssertNotNil(occurrence, "Expected an occurrence insight for the planted trigger")
    XCTAssertGreaterThan(occurrence?.coefficient ?? 0.0, 0.8)
    XCTAssertEqual(occurrence?.bestLagHours, 6)
    XCTAssertGreaterThanOrEqual(occurrence?.eventCount ?? 0, CorrelationEngine.minimumEventCount)
    XCTAssertGreaterThan(occurrence?.positiveMean ?? 0.0, occurrence?.baselineMean ?? 0.0)
  }

  func testEngineGatesInsufficientData() {
    // Too few samples for any test.
    let samples = (0 ..< 5).map { hour in
      CorrelationSample(timestamp: baseDate.addingTimeInterval(Double(hour) * 3600.0), values: [.temperature: Double(hour)])
    }

    let report = CorrelationEngine(samples: samples, episodes: []).computeReport()

    XCTAssertTrue(report.insights.isEmpty)
    XCTAssertTrue(report.insufficient.contains(where: { $0.feature == .temperature }))
  }

  // MARK: Clinician export (Phase 6)

  func testCSVEscaping() {
    XCTAssertEqual(ClinicianReportBuilder.escaped("plain"), "plain")
    XCTAssertEqual(ClinicianReportBuilder.escaped("has, comma"), "\"has, comma\"")
    XCTAssertEqual(ClinicianReportBuilder.escaped("says \"hi\""), "\"says \"\"hi\"\"\"")
    XCTAssertEqual(ClinicianReportBuilder.escaped("line\nbreak"), "\"line\nbreak\"")

    // Formula injection is neutralized with a leading quote so a spreadsheet
    // app renders the value as text instead of evaluating it.
    XCTAssertEqual(ClinicianReportBuilder.escaped("=SUM(A1)"), "'=SUM(A1)")
    XCTAssertEqual(ClinicianReportBuilder.escaped("+1"), "'+1")
    XCTAssertEqual(ClinicianReportBuilder.escaped("-severe"), "'-severe")
    XCTAssertEqual(ClinicianReportBuilder.escaped("@cmd"), "'@cmd")
    // A dangerous prefix combined with a character that needs quoting is both
    // neutralized and RFC-quoted.
    XCTAssertEqual(ClinicianReportBuilder.escaped("=HYPERLINK(\"x\"),y"), "\"'=HYPERLINK(\"\"x\"\"),y\"")
    // A leading digit or letter is untouched (app-generated fields).
    XCTAssertEqual(ClinicianReportBuilder.escaped("2026-07-21"), "2026-07-21")
  }

  // MARK: Insight quality + brief (Phase 3)

  func testRollingZScores() {
    let timestamps = (0 ..< 10).map { baseDate.addingTimeInterval(Double($0) * 86_400.0) }
    let values: [Double] = [10, 10, 12, 8, 10, 10, 10, 10, 10, 20]

    let z = CorrelationMath.rollingZScores(values: values, timestamps: timestamps, minimumCount: 5)

    // First five have too little history.
    for index in 0 ..< 5 {
      XCTAssertNil(z[index])
    }
    // The last value is a strong positive deviation.
    XCTAssertNotNil(z[9])
    XCTAssertGreaterThan(z[9] ?? 0, 2.0)

    // Constant series: std == 0 -> nil.
    let constant = CorrelationMath.rollingZScores(values: [Double](repeating: 5.0, count: 10), timestamps: timestamps, minimumCount: 5)
    XCTAssertTrue(constant[5...].allSatisfy({ $0 == nil }))
  }

  func testPartialCorrelationRemovesConfounder() throws {
    // x and y are both driven by z; their raw correlation is high, but the
    // partial correlation controlling for z collapses.
    var generator = CorrelationMath.SeededGenerator(seed: 7)
    var x = [Double](), y = [Double](), z = [Double]()
    for _ in 0 ..< 200 {
      let driver = Double.random(in: 0 ... 1, using: &generator)
      z.append(driver)
      x.append(driver + Double.random(in: -0.05 ... 0.05, using: &generator))
      y.append(driver + Double.random(in: -0.05 ... 0.05, using: &generator))
    }

    let raw = try XCTUnwrap(CorrelationMath.pearson(x, y))
    let partial = try XCTUnwrap(CorrelationMath.partial(x, y, controlling: z))
    XCTAssertGreaterThan(raw, 0.9)
    XCTAssertLessThan(abs(partial), 0.5 * raw)
  }

  func testEngineAnnotatesConfounder() {
    // Two features that are near-copies of each other, both correlated with
    // onsets: the engine should keep the associations but flag one (or
    // both) as explained by the other.
    let start = baseDate
    var episodes = [HeadacheEpisode]()
    for k in 1 ... 12 {
      let onset = start.addingTimeInterval(Double(k) * 30.0 * 3_600.0)
      episodes.append(HeadacheEpisode(start: onset, end: onset.addingTimeInterval(3_600.0), severities: [HeadacheEpisode.SeverityInterval(severity: .mild, start: onset, end: onset.addingTimeInterval(3_600.0))]))
    }

    var samples = [CorrelationSample]()
    for hour in 0 ..< 380 {
      let timestamp = start.addingTimeInterval(Double(hour) * 3_600.0)
      let preOnset = episodes.contains(where: { $0.start > timestamp && $0.start.timeIntervalSince(timestamp) <= 6.0 * 3_600.0 })
      let signal = (preOnset ? 5.0 : 1.0) + Double(hour % 5) * 0.05
      samples.append(CorrelationSample(timestamp: timestamp, values: [
        .heartRate: signal,
        .respiratoryRate: signal * 0.5 + 0.2
      ]))
    }

    let report = CorrelationEngine(samples: samples, episodes: episodes).computeReport()
    let occurrence = report.insights.filter({ $0.target == .occurrence })
    XCTAssertFalse(occurrence.isEmpty)
    XCTAssertTrue(occurrence.contains(where: { $0.explainedBy != nil }), "Near-duplicate features should be flagged as confounded")
    XCTAssertEqual(report.schemaVersion, InsightsReport.currentSchemaVersion)
    XCTAssertNotNil(report.baselines)
  }

  func testEngineExcludesDisabledFeatures() {
    // Two features carrying identical, strongly predictive data. Disabling one
    // must drop it from the report entirely — not just from the ranked
    // insights, but from the "not enough data" list too, since its historical
    // values are still sitting in the samples.
    let start = baseDate
    var episodes = [HeadacheEpisode]()
    for k in 1 ... 12 {
      let onset = start.addingTimeInterval(Double(k) * 30.0 * 3_600.0)
      episodes.append(HeadacheEpisode(start: onset, end: onset.addingTimeInterval(3_600.0), severities: [HeadacheEpisode.SeverityInterval(severity: .mild, start: onset, end: onset.addingTimeInterval(3_600.0))]))
    }

    var samples = [CorrelationSample]()
    for hour in 0 ..< 380 {
      let timestamp = start.addingTimeInterval(Double(hour) * 3_600.0)
      let preOnset = episodes.contains(where: { $0.start > timestamp && $0.start.timeIntervalSince(timestamp) <= 6.0 * 3_600.0 })
      let signal = (preOnset ? 5.0 : 1.0) + Double(hour % 5) * 0.05
      samples.append(CorrelationSample(timestamp: timestamp, values: [
        .dietaryWater: signal,
        .heartRate: signal
      ]))
    }

    // Baseline: both features are present somewhere in the report.
    let full = CorrelationEngine(samples: samples, episodes: episodes).computeReport()
    let fullFeatures = Set(full.insights.map({ $0.feature })).union(full.insufficient.map({ $0.feature }))
    XCTAssertTrue(fullFeatures.contains(.dietaryWater))
    XCTAssertTrue(fullFeatures.contains(.heartRate))

    // Water turned off: gone from both lists, heart rate untouched.
    var enabled = Set(CorrelationFeature.allCases)
    enabled.remove(.dietaryWater)
    let gated = CorrelationEngine(samples: samples, episodes: episodes, enabledFeatures: enabled).computeReport()

    XCTAssertFalse(gated.insights.contains(where: { $0.feature == .dietaryWater }))
    XCTAssertFalse(gated.insufficient.contains(where: { $0.feature == .dietaryWater }))
    XCTAssertNil(gated.baselines?[.dietaryWater], "A disabled feature must not leak into the brief's baselines")

    let gatedFeatures = Set(gated.insights.map({ $0.feature })).union(gated.insufficient.map({ $0.feature }))
    XCTAssertTrue(gatedFeatures.contains(.heartRate))
  }

  func testCorrelationPreferenceMappingIsTotal() {
    // Every CorrelationFeature must be governed by some toggle: with all of
    // them off, nothing may survive; with all on, everything must.
    let predictors = Preferences.Predictors()
    let keys = Array(predictors.settingsDictionary().keys)
    let saved = keys.reduce(into: [String: Any?]()) { $0[$1] = UserDefaults.standard.object(forKey: $1) }
    defer {
      for key in keys {
        if let value = saved[key] ?? nil {
          UserDefaults.standard.set(value, forKey: key)
        }
        else {
          UserDefaults.standard.removeObject(forKey: key)
        }
      }
    }

    for key in keys {
      UserDefaults.standard.set(false, forKey: key)
    }
    XCTAssertTrue(predictors.enabledCorrelationFeatures().isEmpty, "Every feature should map to a toggle that can disable it")

    for key in keys {
      UserDefaults.standard.set(true, forKey: key)
    }
    XCTAssertEqual(predictors.enabledCorrelationFeatures().count, CorrelationFeature.allCases.count)
  }

  func testInsightsFingerprintIsStableAndDetectsChanges() {
    let all = Set(CorrelationFeature.allCases)

    // Must be deterministic — a Hasher-based fingerprint would differ per
    // process and keep the cache permanently stale.
    XCTAssertEqual(InsightsReport.fingerprint(for: all), InsightsReport.fingerprint(for: all))
    // ...and independent of Set iteration order.
    XCTAssertEqual(
      InsightsReport.fingerprint(for: Set([CorrelationFeature.heartRate, .dietaryWater])),
      InsightsReport.fingerprint(for: Set([CorrelationFeature.dietaryWater, .heartRate])))

    var fewer = all
    fewer.remove(.dietaryWater)
    XCTAssertNotEqual(InsightsReport.fingerprint(for: all), InsightsReport.fingerprint(for: fewer))
  }

  func testInsightsStoreStaleOnPredictorChange() {
    let all = Set(CorrelationFeature.allCases)
    let fingerprint = InsightsReport.fingerprint(for: all)

    let report = InsightsReport(
      generatedAt: Date(),
      rowCount: 42,
      insights: [],
      insufficient: [],
      baselines: nil,
      schemaVersion: InsightsReport.currentSchemaVersion,
      enabledFingerprint: fingerprint)
    InsightsStore.shared.save(report)
    defer { InsightsStore.shared.save(report) }

    XCTAssertFalse(InsightsStore.shared.isStale(rowCount: 42, enabledFingerprint: fingerprint))

    var fewer = all
    fewer.remove(.dietaryWater)
    XCTAssertTrue(
      InsightsStore.shared.isStale(rowCount: 42, enabledFingerprint: InsightsReport.fingerprint(for: fewer)),
      "Turning a predictor off must invalidate the cached report")
  }

  func testDailyMeansBinsAndPreservesGaps() {
    let day = 86_400.0
    let points = [
      // Three readings on day 0 → one point at their mean.
      DatedValue(date: baseDate, value: 1.0),
      DatedValue(date: baseDate.addingTimeInterval(3_600.0), value: 2.0),
      DatedValue(date: baseDate.addingTimeInterval(7_200.0), value: 3.0),
      // A ten-day hole, then one more reading.
      DatedValue(date: baseDate.addingTimeInterval(10.0 * day), value: 7.0)
    ]

    let binned = HeadacheManager.dailyMeans(of: points)
    XCTAssertEqual(binned.count, 2)
    XCTAssertEqual(binned[0].value, 2.0, accuracy: 0.0001)
    XCTAssertEqual(binned[1].value, 7.0, accuracy: 0.0001)
    XCTAssertLessThan(binned[0].date, binned[1].date)
    // The gap survives binning, so the chart can break its line across it.
    XCTAssertGreaterThan(binned[1].date.timeIntervalSince(binned[0].date), 2.0 * day)
  }

  func testLineGraphDrawsSingleSeverity() {
    let start = baseDate
    let span = DateInterval(start: start, end: start.addingTimeInterval(7_200.0))

    // One severity used to produce an empty path — a blank chart on every
    // brand-new headache.
    let single = LineGraph(
      series: [DatedSeverity(date: start, severity: .moderate)],
      span: span,
      gradient: Gradient(colors: [.orange]))
    let points = single.pathPoints()
    XCTAssertGreaterThanOrEqual(points.count, 2, "A single severity must still stroke a line")
    XCTAssertEqual(points.first?.y, points.last?.y, "It should hold flat across the headache")
    XCTAssertEqual(single.loggedPoints().count, 1)
  }

  func testLineGraphSpacesPointsByTime() {
    let start = baseDate
    // Two severities early, one much later: x spacing must reflect the clock,
    // not the index.
    let graph = LineGraph(
      series: [
        DatedSeverity(date: start, severity: .mild),
        DatedSeverity(date: start.addingTimeInterval(600.0), severity: .moderate),
        DatedSeverity(date: start.addingTimeInterval(28_800.0), severity: .severe)
      ],
      span: DateInterval(start: start, end: start.addingTimeInterval(28_800.0)),
      gradient: Gradient(colors: [.red]))

    let xs = graph.loggedPoints().map({ $0.unitPoint.x })
    XCTAssertEqual(xs[0], 0.0, accuracy: 0.0001)
    XCTAssertEqual(xs[1], 600.0 / 28_800.0, accuracy: 0.0001)
    XCTAssertEqual(xs[2], 1.0, accuracy: 0.0001)
    // Index spacing would have put the middle point at 0.5.
    XCTAssertLessThan(xs[1], 0.1)

    // Severe sits at the top of the scale, not-present at the bottom.
    XCTAssertEqual(graph.loggedPoints()[2].unitPoint.y, 1.0, accuracy: 0.0001)
  }

  func testLineGraphHandlesZeroLengthSpan() {
    let graph = LineGraph(
      series: [DatedSeverity(date: baseDate, severity: .mild)],
      span: DateInterval(start: baseDate, end: baseDate),
      gradient: Gradient(colors: [.red]))
    // Must not divide by zero or produce NaN unit points.
    for point in graph.pathPoints() {
      XCTAssertFalse(point.x.isNaN)
      XCTAssertFalse(point.y.isNaN)
    }
  }

  func testBriefBuilder() {
    let insight = TriggerInsight(
      feature: .sleepSeconds,
      target: .occurrence,
      coefficient: -0.5,
      qValue: 0.01,
      bestLagHours: 24,
      lagProfile: [24: -0.5],
      sampleCount: 100,
      eventCount: 20,
      positiveMean: 5.0 * 3_600.0,
      baselineMean: 7.0 * 3_600.0,
      usesBaselineRelative: true,
      explainedBy: nil,
      partialCoefficient: nil)

    let report = InsightsReport(
      generatedAt: baseDate,
      rowCount: 100,
      insights: [insight],
      insufficient: [],
      baselines: [.sleepSeconds: FeatureBaseline(mean: 7.0 * 3_600.0, std: 3_600.0, count: 14)],
      schemaVersion: InsightsReport.currentSchemaVersion,
      enabledFingerprint: nil)

    let risk = RiskPrediction(input: .empty, probability: 0.7, topFactors: [], computedAt: baseDate)

    // Short sleep (negative deviation) matches the negative association.
    let shortSleep = RiskBriefBuilder.makeBrief(risk: risk, todayValues: [.sleepSeconds: 4.5 * 3_600.0], report: report)
    XCTAssertEqual(shortSleep?.tier, .high)
    XCTAssertEqual(shortSleep?.reasons.count, 1)

    // Long sleep deviates but in the protective direction: no reason.
    let longSleep = RiskBriefBuilder.makeBrief(risk: risk, todayValues: [.sleepSeconds: 9.5 * 3_600.0], report: report)
    XCTAssertEqual(longSleep?.reasons.count, 0)

    // Within a standard deviation: no reason.
    let normalSleep = RiskBriefBuilder.makeBrief(risk: risk, todayValues: [.sleepSeconds: 6.8 * 3_600.0], report: report)
    XCTAssertEqual(normalSleep?.reasons.count, 0)

    // Empty prediction: no brief.
    XCTAssertNil(RiskBriefBuilder.makeBrief(risk: .empty, todayValues: [:], report: report))
  }

  func testLegacyReportDecodes() throws {
    // A report shaped like the pre-Phase-3 cache: no baselines, no
    // schemaVersion, insights without the new fields.
    let json = """
    {"generatedAt": 700000000, "rowCount": 10, "insights": [], "insufficient": []}
    """
    let decoder = JSONDecoder()
    let report = try decoder.decode(InsightsReport.self, from: Data(json.utf8))
    XCTAssertNil(report.schemaVersion)
    XCTAssertNil(report.baselines)
    XCTAssertEqual(report.rowCount, 10)
  }

  // MARK: Risk model (Phase 2)

  func testPlattCalibrationRecoversMonotoneMapping() throws {
    // Synthetic overconfident scores: true probability is a tempered version
    // of the raw score.
    var scores = [Double]()
    var outcomes = [Bool]()
    var seed = CorrelationMath.SeededGenerator(seed: 42)

    for i in 0 ..< 200 {
      let raw = Double(i % 100) / 100.0 * 0.9 + 0.05
      let trueProbability = 0.5 + (raw - 0.5) * 0.5
      scores.append(raw)
      outcomes.append(Double.random(in: 0 ... 1, using: &seed) < trueProbability)
    }

    let calibration = try XCTUnwrap(PlattCalibration.fit(scores: scores, outcomes: outcomes))

    // Calibration must be monotone and reduce the Brier score.
    XCTAssertLessThan(calibration.apply(0.2), calibration.apply(0.8))
    let rawBrier = try XCTUnwrap(PlattCalibration.brier(probabilities: scores, outcomes: outcomes))
    let calibratedBrier = try XCTUnwrap(PlattCalibration.brier(probabilities: scores.map(calibration.apply), outcomes: outcomes))
    XCTAssertLessThanOrEqual(calibratedBrier, rawBrier)
  }

  func testPlattCalibrationDegenerateFallback() {
    // Fewer than 5 positives: no fit.
    XCTAssertNil(PlattCalibration.fit(scores: [0.1, 0.9, 0.2, 0.8], outcomes: [false, true, false, true]))
    XCTAssertEqual(PlattCalibration.identity.apply(0.42), 0.42, accuracy: 0.0001)
  }

  func testBrierAndBuckets() throws {
    let probabilities = [0.1, 0.9, 0.5, 0.5]
    let outcomes = [false, true, true, false]
    let brier = try XCTUnwrap(PlattCalibration.brier(probabilities: probabilities, outcomes: outcomes))
    // (0.01 + 0.01 + 0.25 + 0.25) / 4
    XCTAssertEqual(brier, 0.13, accuracy: 0.0001)

    let buckets = PlattCalibration.buckets(probabilities: probabilities, outcomes: outcomes, count: 5)
    XCTAssertEqual(buckets.count, 3)
    let middle = try XCTUnwrap(buckets.first(where: { $0.lowerBound == 0.4 }))
    XCTAssertEqual(middle.count, 2)
    XCTAssertEqual(middle.observedRate, 0.5, accuracy: 0.0001)

    XCTAssertNil(PlattCalibration.brier(probabilities: [], outcomes: []))
  }

  func testRiskTierBoundaries() {
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 0.0), .low)
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 0.2999), .low)
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 0.30), .elevated)
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 0.5999), .elevated)
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 0.60), .high)
    XCTAssertEqual(RiskPrediction.RiskTier(probability: 1.0), .high)
  }

  func testRiskPredictionEqualityIgnoresComputedAt() {
    let a = RiskPrediction(input: .empty, probability: 0.5, topFactors: [], computedAt: baseDate)
    let b = RiskPrediction(input: .empty, probability: 0.5, topFactors: [], computedAt: baseDate.addingTimeInterval(999.0))
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, RiskPrediction.empty)
  }

  // MARK: Data capture (Phase 1)

  func testNewMetricPresenceBitsRoundTrip() {
    let health = HealthData(context: context)
    health.updateWithHealthKitData([
      .dietaryCaffeine: 120.0,
      .dietaryWater: 1500.0,
      .timeInDaylight: 45.0,
      .appleExerciseTime: 30.0,
      .menstrualDaysSinceCycleStart: 4.0,
      .menstrualFlowActive: 1.0
    ], at: baseDate)

    let data = health.healthKitData
    XCTAssertEqual(data[.dietaryCaffeine], 120.0)
    XCTAssertEqual(data[.dietaryWater], 1500.0)
    XCTAssertEqual(data[.timeInDaylight], 45.0)
    XCTAssertEqual(data[.appleExerciseTime], 30.0)
    XCTAssertEqual(data[.menstrualDaysSinceCycleStart], 4.0)
    XCTAssertEqual(data[.menstrualFlowActive], 1.0)
    XCTAssertNil(data[.heartRate], "Absent metrics stay absent")
  }

  func testCorrelationSampleSurfacesNewFeatures() {
    let trainingData = TrainingData(context: context)
    trainingData.timestamp = baseDate
    trainingData.updateWithHealthKitData([
      .dietaryCaffeine: 200.0,
      .appleExerciseTime: 20.0,
      .bodyTemperature: 36.7,
      .wristTemperature: 35.1,
      .basalBodyTemperature: 36.5,
      .hrvRMSSD: 42.0,
      .hrvPNN50: 0.2,
      .hrvLFHF: 1.4
    ], at: baseDate)

    let sample = trainingData.correlationSample
    XCTAssertEqual(sample?.values[.dietaryCaffeine], 200.0)
    XCTAssertEqual(sample?.values[.exerciseMinutes], 20.0)
    // Temperature + beat-to-beat HRV now surface through the correlation engine.
    XCTAssertEqual(sample?.values[.bodyTemperature], 36.7)
    XCTAssertEqual(sample?.values[.wristTemperature], 35.1)
    XCTAssertEqual(sample?.values[.basalBodyTemperature], 36.5)
    XCTAssertEqual(sample?.values[.hrvRMSSD], 42.0)
    XCTAssertEqual(sample?.values[.hrvPNN50], 0.2)
    XCTAssertEqual(sample?.values[.hrvLFHF], 1.4)
  }

  func testCorrelationFeatureMatching() {
    // Exact raw column names.
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "Resting Heart Rate"), .restingHeartRate)
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "HRV RMSSD"), .hrvRMSSD)
    // Baseline-relative columns strip to their base metric.
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "HRV RMSSD Baseline Z"), .hrvRMSSD)
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "Body Temperature Baseline Slope"), .bodyTemperature)
    // Abbreviated bases resolve via the alias map.
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "HRV Baseline Z"), .heartRateVariability)
    XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: "Sleep Baseline Slope"), .sleepSeconds)
    // Unknown columns don't match.
    XCTAssertNil(CorrelationFeature.matching(mlFeatureName: "Nonsense Column"))
  }

  func testDerivedMetricQueryReturnsNilWithoutCompletion() {
    // A derived metric (beat-to-beat HRV) has no HealthKit type, so `query`
    // must return nil WITHOUT invoking completion — otherwise the read loop
    // both leaves the dispatch group (via completion) and leaves again on the
    // nil return, over-releasing the group and crashing.
    for metric in [HealthKitData.hrvRMSSD, .hrvPNN50, .hrvLFHF] {
      var completionCalled = false
      let query = metric.query(endingAt: baseDate) { _, _, _, _ in completionCalled = true }
      XCTAssertNil(query, "\(metric) should build no query")
      XCTAssertFalse(completionCalled, "\(metric) must not invoke completion on its nil return")
    }

    // A real quantity metric still builds a query.
    XCTAssertNotNil(HealthKitData.restingHeartRate.query(endingAt: baseDate) { _, _, _, _ in })
  }

  /// A store created with the temperature-only 2.2 model (the schema an
  /// existing device sits on) must open and lightweight-migrate to the final
  /// 2.3 model with every row intact. This is the recovery path for stores
  /// stranded by the earlier in-place mutation of 2.2.
  func testStoreMigrates22To23PreservingData() throws {
    let momdURL = try XCTUnwrap(Bundle.main.url(forResource: "Headache_Tracker", withExtension: "momd"))
    let model22 = try XCTUnwrap(NSManagedObjectModel(contentsOf: momdURL.appendingPathComponent("Headache_Tracker 2.2.mom")))
    let model23 = try XCTUnwrap(NSManagedObjectModel(contentsOf: momdURL.appendingPathComponent("Headache_Tracker 2.3.mom")))

    let storeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("migration-\(UUID().uuidString).sqlite")
    defer {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
      }
    }

    // 1) Create a 2.2 store (single combined store, as with sync off) and add data.
    let coordinator22 = NSPersistentStoreCoordinator(managedObjectModel: model22)
    try coordinator22.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
    let context22 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context22.persistentStoreCoordinator = coordinator22

    let headacheID = UUID()
    let headache = NSEntityDescription.insertNewObject(forEntityName: "Headache", into: context22)
    headache.setValue(headacheID, forKey: "identifier")
    headache.setValue("migraine, left side", forKey: "notes")
    let evaluation = NSEntityDescription.insertNewObject(forEntityName: "Evaluation", into: context22)
    evaluation.setValue(0.42, forKey: "predictedProbability")
    try context22.save()
    for store in coordinator22.persistentStores {
      try coordinator22.remove(store)
    }

    // 2) Open the SAME file with 2.3 + automatic lightweight migration.
    let coordinator23 = NSPersistentStoreCoordinator(managedObjectModel: model23)
    try coordinator23.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: [
      NSMigratePersistentStoresAutomaticallyOption: true,
      NSInferMappingModelAutomaticallyOption: true
    ])
    let context23 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context23.persistentStoreCoordinator = coordinator23

    // 3) Every row survived the migration.
    let headaches = try context23.fetch(NSFetchRequest<NSManagedObject>(entityName: "Headache"))
    XCTAssertEqual(headaches.count, 1)
    XCTAssertEqual(headaches.first?.value(forKey: "identifier") as? UUID, headacheID)
    XCTAssertEqual(headaches.first?.value(forKey: "notes") as? String, "migraine, left side")

    let evals = try context23.fetch(NSFetchRequest<NSManagedObject>(entityName: "Evaluation"))
    XCTAssertEqual(evals.count, 1)
    XCTAssertEqual(evals.first?.value(forKey: "predictedProbability") as? Double, 0.42)

    // The 2.3 schema really is the richer one (added columns are present).
    XCTAssertNotNil(model23.entitiesByName["HealthData"]?.attributesByName["hrvRMSSD"])
    XCTAssertNotNil(model23.entitiesByName["Evaluation"]?.attributesByName["horizonHours"])
    XCTAssertNil(model22.entitiesByName["HealthData"]?.attributesByName["hrvRMSSD"], "2.2 must be the temperature-only schema")
  }

  func testMenstrualHelpers() throws {
    let type = try XCTUnwrap(HKObjectType.categoryType(forIdentifier: .menstrualFlow))
    let cycleStart = baseDate

    let flagged = HKCategorySample(
      type: type,
      value: HKCategoryValueMenstrualFlow.medium.rawValue,
      start: cycleStart,
      end: cycleStart.addingTimeInterval(86_400.0),
      metadata: [HKMetadataKeyMenstrualCycleStart: true])
    let followUp = HKCategorySample(
      type: type,
      value: HKCategoryValueMenstrualFlow.light.rawValue,
      start: cycleStart.addingTimeInterval(86_400.0),
      end: cycleStart.addingTimeInterval(2.0 * 86_400.0),
      metadata: [HKMetadataKeyMenstrualCycleStart: false])

    let asOf = cycleStart.addingTimeInterval(5.0 * 86_400.0)

    // Metadata-flagged start wins.
    let days = HealthKitManager.daysSinceCycleStart(from: [flagged, followUp], asOf: asOf)
    XCTAssertEqual(try XCTUnwrap(days), 5.0, accuracy: 0.001)

    // Fallback: no flagged start, consecutive run start. (HealthKit requires
    // the metadata key on creation, so "unflagged" means false, not absent.)
    let unflagged1 = HKCategorySample(type: type, value: HKCategoryValueMenstrualFlow.medium.rawValue, start: cycleStart, end: cycleStart.addingTimeInterval(86_400.0), metadata: [HKMetadataKeyMenstrualCycleStart: false])
    let unflagged2 = HKCategorySample(type: type, value: HKCategoryValueMenstrualFlow.light.rawValue, start: cycleStart.addingTimeInterval(86_400.0), end: cycleStart.addingTimeInterval(2.0 * 86_400.0), metadata: [HKMetadataKeyMenstrualCycleStart: false])
    let fallbackDays = HealthKitManager.daysSinceCycleStart(from: [unflagged1, unflagged2], asOf: asOf)
    XCTAssertEqual(try XCTUnwrap(fallbackDays), 5.0, accuracy: 0.001)

    // Flow active within 24h vs. not vs. untracked.
    XCTAssertEqual(HealthKitManager.menstrualFlowActive(from: [flagged], asOf: cycleStart.addingTimeInterval(3_600.0)), true)
    XCTAssertEqual(HealthKitManager.menstrualFlowActive(from: [flagged], asOf: asOf), false)
    XCTAssertNil(HealthKitManager.menstrualFlowActive(from: [], asOf: asOf))
  }

  func testMedicationRankingAndCascade() throws {
    let headache = makeHeadache()

    let older = MedicationEntry(context: context, name: "Sumatriptan", takenAt: baseDate)
    let newer = MedicationEntry(context: context, name: "Ibuprofen", takenAt: baseDate.addingTimeInterval(3_600.0))
    let duplicate = MedicationEntry(context: context, name: "SUMATRIPTAN", takenAt: baseDate.addingTimeInterval(7_200.0))
    headache.addToMedications(older)
    headache.addToMedications(newer)
    headache.addToMedications(duplicate)

    XCTAssertEqual(older.efficacy, .unrated)
    older.efficacy = .helpful
    XCTAssertEqual(older.efficacyRaw, MedicationEntry.Efficacy.helpful.rawValue)

    // Ranking: most recent first, case-insensitive dedupe.
    let ranked = HeadacheManager.rankedMedicationNames(from: [duplicate, newer, older], limit: 8)
    XCTAssertEqual(ranked, ["SUMATRIPTAN", "Ibuprofen"])

    // Canonical name matches most recent casing.
    try context.save()
    XCTAssertEqual(HeadacheManager.canonicalMedicationName(for: "sumatriptan", in: context), "SUMATRIPTAN")

    // Deleting the headache cascades its medication entries.
    context.delete(headache)
    try context.save()
    let remaining = try context.fetch(MedicationEntry.fetchRequest())
    XCTAssertTrue(remaining.isEmpty)
  }

  // MARK: Home digest, milestones, days-free (Sprint U1)

  func testDaysHeadacheFree() {
    XCTAssertNil(HeadacheManager.daysHeadacheFree(since: nil, now: baseDate))
    XCTAssertEqual(HeadacheManager.daysHeadacheFree(since: baseDate.addingTimeInterval(-5 * 86400), now: baseDate), 5)
    // Ended in the future / just now → 0, not negative.
    XCTAssertEqual(HeadacheManager.daysHeadacheFree(since: baseDate, now: baseDate), 0)
    XCTAssertEqual(HeadacheManager.daysHeadacheFree(since: baseDate.addingTimeInterval(3600), now: baseDate), 0)
  }

  func testRiskDigest() {
    func risk(_ p: Double) -> RiskPrediction { RiskPrediction(input: .empty, probability: p, topFactors: [], computedAt: baseDate) }

    // A meaningful drop is surfaced.
    let dropped = RiskDigest.make(current: risk(0.30), lastSeen: risk(0.50), currentTriggers: [], lastTriggers: [])
    XCTAssertEqual(dropped.lines, ["Risk is down 20% since you last checked."])

    // A tiny change is not.
    XCTAssertTrue(RiskDigest.make(current: risk(0.31), lastSeen: risk(0.30), currentTriggers: [], lastTriggers: []).isEmpty)

    // No last-seen forecast → no risk line.
    XCTAssertTrue(RiskDigest.make(current: risk(0.30), lastSeen: nil, currentTriggers: [], lastTriggers: []).isEmpty)

    // A newly-appeared trigger is called out.
    let newTrigger = RiskDigest.make(current: risk(0.30), lastSeen: risk(0.30), currentTriggers: [.sleepSeconds], lastTriggers: [])
    XCTAssertTrue(newTrigger.lines.contains(where: { $0.contains("Sleep Duration") }))
  }

  func testModelMilestone() {
    // First model turning on.
    XCTAssertEqual(ModelMilestone.evaluate(hadModel: false, hasModel: true, previousAccuracy: nil, currentAccuracy: 0.6)?.message.contains("just turned on"), true)
    // Accuracy improvement.
    XCTAssertEqual(ModelMilestone.evaluate(hadModel: true, hasModel: true, previousAccuracy: 0.60, currentAccuracy: 0.72)?.message.contains("right 72%"), true)
    // No milestone for a small change.
    XCTAssertNil(ModelMilestone.evaluate(hadModel: true, hasModel: true, previousAccuracy: 0.70, currentAccuracy: 0.71))
    // No model, no milestone.
    XCTAssertNil(ModelMilestone.evaluate(hadModel: false, hasModel: false, previousAccuracy: nil, currentAccuracy: nil))
  }

  func testFormatTimeWithDay() {
    let now = Date()
    // A time today is shown without a date (no "at" separator).
    XCTAssertFalse(Formatters.formatTimeWithDay(now).contains(" at "))
    XCTAssertEqual(Formatters.formatTimeWithDay(now), Formatters.formatTime(now))

    // A time on another day carries the date so it isn't ambiguous.
    let threeDaysAgo = now.addingTimeInterval(-3.0 * 86400.0)
    XCTAssertTrue(Formatters.formatTimeWithDay(threeDaysAgo).contains(" at "))
    XCTAssertTrue(Formatters.formatTimeWithDay(threeDaysAgo).contains(Formatters.formatTime(threeDaysAgo)))
  }

  func testReportSpannedDays() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let day0 = Date(timeIntervalSince1970: 0.0)  // 1970-01-01 00:00 UTC

    // A same-day span counts one day.
    XCTAssertEqual(ClinicianReportData.spannedDays(from: day0.addingTimeInterval(3600.0), through: day0.addingTimeInterval(7200.0), calendar: calendar).count, 1)
    // A span crossing midnight counts both days.
    XCTAssertEqual(ClinicianReportData.spannedDays(from: day0.addingTimeInterval(23.0 * 3600.0), through: day0.addingTimeInterval(25.0 * 3600.0), calendar: calendar).count, 2)
    // A span covering parts of three days counts three.
    XCTAssertEqual(ClinicianReportData.spannedDays(from: day0, through: day0.addingTimeInterval(2.0 * 86400.0 + 3600.0), calendar: calendar).count, 3)
    // An end before the start is clamped to just the start day.
    XCTAssertEqual(ClinicianReportData.spannedDays(from: day0.addingTimeInterval(86400.0), through: day0, calendar: calendar).count, 1)
  }

  func testRelativeDateDescriptionFutureIsPositive() {
    let calendar = Calendar.current

    // A future onset must read "In 3 days", not "In -3 days" (days is negative
    // for future dates, so the branch has to negate it).
    let ahead = calendar.date(byAdding: .day, value: 3, to: Date())!
    let future = calendar.relativeDateDescription(ahead)
    XCTAssertTrue(future.contains("In 3 days"), "Expected 'In 3 days', got: \(future)")

    // The past branch keeps working.
    let ago = calendar.date(byAdding: .day, value: -3, to: Date())!
    XCTAssertTrue(calendar.relativeDateDescription(ago).contains("3 days ago"), "Expected '3 days ago'.")

    // Adjacent days use the named forms.
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    XCTAssertTrue(calendar.relativeDateDescription(tomorrow).hasPrefix("Tomorrow at"))
  }

  func testMidnightAfterAcrossDST() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!

    // Spring forward: 2026-03-08 02:00 → 03:00 (a 23-hour day). A flat +86,400s
    // from late on the 7th skips a wall-clock hour and lands on the 9th, so the
    // next-midnight must come from calendar-aware day arithmetic instead.
    var comps = DateComponents()
    comps.year = 2026; comps.month = 3; comps.day = 7
    comps.hour = 23; comps.minute = 30
    let lateNight = calendar.date(from: comps)!

    let midnight = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: calendar.midnightAfter(lateNight))
    XCTAssertEqual(midnight.year, 2026)
    XCTAssertEqual(midnight.month, 3)
    XCTAssertEqual(midnight.day, 8)  // the very next calendar day, not the 9th
    XCTAssertEqual(midnight.hour, 0)
    XCTAssertEqual(midnight.minute, 0)

    // A normal day still advances exactly one calendar day.
    comps.month = 6; comps.day = 15
    let normalNext = calendar.dateComponents([.month, .day], from: calendar.midnightAfter(calendar.date(from: comps)!))
    XCTAssertEqual(normalNext.month, 6)
    XCTAssertEqual(normalNext.day, 16)
  }

  // MARK: Monthly recap aggregation (Sprint U6)

  func testMonthlyRecap() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let monthStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!  // June: 30 days
    let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!        // whole month observed

    func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 6, day: d))! }

    // Two headaches: June 3 (same day) and June 10 20:00 → June 11 02:00.
    let episodes = [
      DateInterval(start: day(3).addingTimeInterval(9 * 3600), end: day(3).addingTimeInterval(14 * 3600)),
      DateInterval(start: day(10).addingTimeInterval(20 * 3600), end: day(11).addingTimeInterval(2 * 3600))
    ]
    let recap = MonthlyRecap.make(
      monthStart: monthStart,
      now: now,
      calendar: calendar,
      episodes: episodes,
      patterns: ["Lower sleep before headaches", "Higher stress before headaches"])

    XCTAssertEqual(recap.totalDays, 30)
    XCTAssertEqual(recap.headacheCount, 2)
    // Headache days: June 3, 10, 11 → 3; free = 27.
    XCTAssertEqual(recap.headacheFreeDays, 27)
    // Free runs: [1-2]=2, [4-9]=6, [12-30]=19 → longest 19.
    XCTAssertEqual(recap.longestFreeStreak, 19)
    XCTAssertEqual(recap.topPatterns.count, 2)
    XCTAssertEqual(recap.worstWeek?.onsets, 1)
    XCTAssertEqual(recap.bestWeek?.onsets, 0)
    XCTAssertTrue(recap.hasData)

    // Empty month → no data.
    let empty = MonthlyRecap.make(monthStart: monthStart, now: now, calendar: calendar, episodes: [], patterns: [])
    XCTAssertFalse(empty.hasData)
    XCTAssertEqual(empty.headacheFreeDays, 30)
    XCTAssertNil(empty.bestWeek)
  }

  // MARK: Signals view — domains, attribution, profile (Phase 6)

  private func insight(_ feature: CorrelationFeature, coefficient: Double, qValue: Double, target: TriggerInsight.Target = .occurrence, explainedBy: CorrelationFeature? = nil) -> TriggerInsight {
    TriggerInsight(feature: feature, target: target, coefficient: coefficient, qValue: qValue, bestLagHours: 24, lagProfile: [24: coefficient], sampleCount: 50, eventCount: 15, positiveMean: 1.0, baselineMean: 0.0, usesBaselineRelative: true, explainedBy: explainedBy, partialCoefficient: nil)
  }

  func testCorrelationFeatureDomains() {
    XCTAssertEqual(CorrelationFeature.sleepSeconds.domain, .sleep)
    XCTAssertEqual(CorrelationFeature.heartRateVariability.domain, .autonomic)
    XCTAssertEqual(CorrelationFeature.bodyTemperature.domain, .autonomic)
    XCTAssertEqual(CorrelationFeature.pressure.domain, .weather)
    XCTAssertEqual(CorrelationFeature.menstrualFlowActive.domain, .cycle)
    XCTAssertEqual(CorrelationFeature.dietaryCaffeine.domain, .lifestyle)
  }

  func testWeatherDevicePressurePreservedOnHistoricalRefetch() {
    let weather = WeatherData(context: context)

    // Initial capture includes the phone's real barometer reading.
    weather.updateWithWeatherStatistics(
      WeatherStatistics(barometricPressure: 100.0, currentPressure: 1013.0, currentHumidity: 0.5, currentTemperature: 20.0, sigmaPressure: 0.1, sigmaHumidity: 0.1, sigmaTemperature: 1.0),
      at: baseDate)
    XCTAssertEqual(weather.devicePressure, 100.0)
    XCTAssertTrue(weather.presence.contains(.devicePressure))

    // A historical re-fetch (no device barometer for a past date) must correct
    // the station weather while preserving the device pressure and its bit.
    weather.updateWithWeatherStatistics(
      WeatherStatistics(barometricPressure: nil, currentPressure: 995.0, currentHumidity: 0.8, currentTemperature: 8.0, sigmaPressure: 0.2, sigmaHumidity: 0.2, sigmaTemperature: 2.0),
      at: baseDate)
    XCTAssertEqual(weather.devicePressure, 100.0)              // preserved
    XCTAssertTrue(weather.presence.contains(.devicePressure))  // still present
    XCTAssertEqual(weather.pressure, 995.0)                    // station corrected
    XCTAssertEqual(weather.temperature, 8.0)
    XCTAssertEqual(weather.humidity, 0.8)
  }

  // MARK: What-if simulator

  func testModelInputPersistsPreviousHealthKitData() throws {
    // Regression guard: `previousHealthKitData` used to be excluded from
    // CodingKeys, so a prediction decoded from the shared defaults lost every
    // baseline *slope* (they need a prior reading) and the ten
    // "… Baseline Slope" columns silently pinned to 0 — which made the what-if
    // explorer far less responsive than the real hourly forecast.
    let input = ModelInput(
      date: baseDate,
      location: nil,
      weatherStatistics: nil,
      healthKitData: [.sleepSeconds: 7.0 * 3_600.0, .heartRateVariabilitySDNN: 44.0],
      previousHealthKitData: [.heartRateVariabilitySDNN: 61.0, .sleepSeconds: 6.0 * 3_600.0])

    let decoded = try JSONDecoder().decode(ModelInput.self, from: try JSONEncoder().encode(input))
    XCTAssertEqual(decoded.previousHealthKitData?[.heartRateVariabilitySDNN], 61.0)
    XCTAssertEqual(decoded.previousHealthKitData?[.sleepSeconds], 6.0 * 3_600.0)
  }

  func testWhatIfSweepValuesSpanRangeInclusively() {
    let values = WhatIfView.sweepValues(in: 0.0 ... 12.0, count: 13)
    XCTAssertEqual(values.count, 13)
    XCTAssertEqual(values.first ?? -1, 0.0, accuracy: 0.0001)
    XCTAssertEqual(values.last ?? -1, 12.0, accuracy: 0.0001)
    XCTAssertEqual(values[1] - values[0], 1.0, accuracy: 0.0001)
    // Degenerate count must not divide by zero.
    XCTAssertEqual(WhatIfView.sweepValues(in: 0.0 ... 12.0, count: 1), [0.0])
  }

  func testWhatIfRankingPrefersContributionsThenImportances() {
    let candidates: [RiskSignal] = [
      .health(.sleepSeconds),
      .health(.heartRateVariabilitySDNN),
      .health(.restingHeartRate),
      .weather(.currentPressure)
    ]

    // Resting HR is what's driving *this* forecast, so it outranks sleep even
    // though sleep dominates the model globally.
    let contributions = [
      RiskPrediction.RiskContribution(feature: .restingHeartRate, mlFeatureName: "Resting Heart Rate", delta: 0.09)
    ]
    let importances = [
      "Sleep Baseline Z": 1.0,          // collapses onto .sleepSeconds
      "Heart Rate Variability": 0.5
    ]

    let ranked = WhatIfView.rankSignals(candidates: candidates, contributions: contributions, importances: importances, limit: 4)
    let features = ranked.compactMap({ $0.correlationFeature })

    XCTAssertEqual(features.first, .restingHeartRate, "A contribution must outrank any importance")
    XCTAssertEqual(features.dropFirst().first, .sleepSeconds, "A baseline-Z column must rank its base metric")
    XCTAssertEqual(features.dropFirst(2).first, .heartRateVariability)
    // Current pressure has neither a contribution nor an importance, but it is
    // in the static fallback, so it still appears — last.
    XCTAssertEqual(features.last, .pressure)
  }

  func testWhatIfRankingFallsBackAndRespectsLimit() {
    let candidates: [RiskSignal] = [
      .weather(.currentPressure),
      .health(.sleepSeconds),
      .health(.heartRateVariabilitySDNN),
      .health(.oxygenSaturation)
    ]

    // No model yet: the static trio orders the list and the unranked signal
    // (oxygen saturation) is dropped rather than offered arbitrarily.
    let ranked = WhatIfView.rankSignals(candidates: candidates, contributions: [], importances: [:], limit: 4)
    XCTAssertEqual(ranked.compactMap({ $0.correlationFeature }), [.sleepSeconds, .pressure, .heartRateVariability])

    let limited = WhatIfView.rankSignals(candidates: candidates, contributions: [], importances: [:], limit: 2)
    XCTAssertEqual(limited.count, 2)
  }

  func testRiskSignalPlausibleBounds() throws {
    // Sleep is stored in seconds, so its bounds must be too — an hours-vs-
    // seconds mixup would make the slider useless.
    let sleep = try XCTUnwrap(RiskSignal.health(.sleepSeconds).plausibleBounds)
    XCTAssertEqual(sleep.upperBound, 14.0 * 3_600.0)
    XCTAssertEqual(RiskSignal.weather(.humidity).plausibleBounds?.upperBound, 1.0)
    XCTAssertNotNil(RiskSignal.health(.heartRateVariabilitySDNN).plausibleBounds)
    // Correlation-only metrics feed no model column, so they have no range.
    XCTAssertNil(RiskSignal.health(.dietaryWater).plausibleBounds)
  }

  func testWeatherFieldValueRoundTripsThroughSettingValue() {
    let statistics = WeatherStatistics(
      barometricPressure: 100.1,
      currentPressure: 101.3,
      currentHumidity: 0.5,
      currentTemperature: 20.0,
      sigmaPressure: 0.2,
      sigmaHumidity: 0.1,
      sigmaTemperature: 1.0)
    let input = ModelInput(date: baseDate, location: nil, weatherStatistics: statistics, healthKitData: nil)

    for field in WeatherField.allCases {
      let changed = input.settingValue(42.0, for: .weather(field))
      XCTAssertEqual(changed.weatherStatistics.flatMap({ field.value(from: $0) }), 42.0, "\(field) did not round-trip")
    }
  }

  func testWhatIfStubScoresRespondToChangedInput() async throws {
    // The simulator stub used to return the published probability regardless
    // of input, so every slider position produced an identical number and the
    // screen looked broken. It must respond.
    let predictor = Predictor()
    let base = ModelInput(
      date: baseDate,
      location: nil,
      weatherStatistics: nil,
      healthKitData: [.sleepSeconds: 7.0 * 3_600.0, .heartRateVariabilitySDNN: 45.0])

    let rested = try await predictor.probability(for: base.settingValue(9.0 * 3_600.0, for: .health(.sleepSeconds)))
    let deprived = try await predictor.probability(for: base.settingValue(3.0 * 3_600.0, for: .health(.sleepSeconds)))
    XCTAssertGreaterThan(deprived, rested, "Less sleep should read as more risk")

    // Time of day is a model feature in its own right — the input that moves
    // by construction on every hourly refresh.
    var morning = base
    morning.date = Calendar.current.startOfDay(for: baseDate).addingTimeInterval(4.0 * 3_600.0)
    var afternoon = base
    afternoon.date = Calendar.current.startOfDay(for: baseDate).addingTimeInterval(14.0 * 3_600.0)
    let scores = try await predictor.probabilities(for: [morning, afternoon])
    XCTAssertEqual(scores.count, 2)
    XCTAssertGreaterThan(abs(scores[0] - scores[1]), 0.01, "Time of day must move the score")

    let empty = try await predictor.probabilities(for: [])
    XCTAssertEqual(empty.count, 0)
  }

  func testCorrelationFeatureFromHealthKitData() {
    XCTAssertEqual(CorrelationFeature(healthKitData: .heartRateVariabilitySDNN), .heartRateVariability)
    XCTAssertEqual(CorrelationFeature(healthKitData: .appleExerciseTime), .exerciseMinutes)
    XCTAssertEqual(CorrelationFeature(healthKitData: .bodyTemperature), .bodyTemperature)
    XCTAssertEqual(CorrelationFeature(healthKitData: .sleepOnset), .sleepOnsetHour)
    XCTAssertNil(CorrelationFeature(healthKitData: .headache))
  }

  func testModelInputNeutralizing() {
    var medians = FeatureMedians()
    medians.healthKit[.restingHeartRate] = 55.0
    medians.temperature = 20.0

    let input = ModelInput(
      date: baseDate,
      location: nil,
      weatherStatistics: WeatherStatistics(barometricPressure: 1020.0, currentPressure: 1020.0, currentHumidity: 0.8, currentTemperature: 33.0, sigmaPressure: 0.1, sigmaHumidity: 0.1, sigmaTemperature: 5.0),
      healthKitData: [.restingHeartRate: 80.0, .heartRate: 70.0],
      baselineZ: [.restingHeartRate: 2.0],
      baselineSlope: [.restingHeartRate: 1.0])

    // Neutralizing a HealthKit metric: raw -> median, baseline z/slope dropped,
    // other metrics untouched.
    let neutralHR = input.neutralizing(.health(.restingHeartRate), medians: medians)
    XCTAssertEqual(neutralHR.healthKitData?[.restingHeartRate], 55.0)
    XCTAssertNil(neutralHR.baselineZ?[.restingHeartRate])
    XCTAssertNil(neutralHR.baselineSlope?[.restingHeartRate])
    XCTAssertEqual(neutralHR.healthKitData?[.heartRate], 70.0)

    // Neutralizing a weather field swaps just that field.
    let neutralTemp = input.neutralizing(.weather(.temperature), medians: medians)
    XCTAssertEqual(neutralTemp.weatherStatistics?.currentTemperature, 20.0)
    XCTAssertEqual(neutralTemp.weatherStatistics?.currentHumidity, 0.8)

    // Candidates: present modeled metrics + weather fields; excludes the
    // correlation-only metrics with no model column.
    let candidateFeatures = input.attributionCandidates().compactMap { $0.correlationFeature }
    XCTAssertTrue(candidateFeatures.contains(.restingHeartRate))
    XCTAssertTrue(candidateFeatures.contains(.temperature))

    // settingValue (what-if): set arbitrary value + drop baseline so the
    // scorer recomputes it; other fields untouched.
    let more = input.settingValue(8 * 3600, for: .health(.restingHeartRate))
    XCTAssertEqual(more.healthKitData?[.restingHeartRate], 8 * 3600)
    XCTAssertNil(more.baselineZ?[.restingHeartRate])
    let lowerPressure = input.settingValue(98, for: .weather(.currentPressure))
    XCTAssertEqual(lowerPressure.weatherStatistics?.currentPressure, 98)
    XCTAssertEqual(lowerPressure.weatherStatistics?.currentHumidity, 0.8)
  }

  func testInsightsReportDomainProfile() {
    let report = InsightsReport(
      generatedAt: baseDate,
      rowCount: 100,
      insights: [
        insight(.sleepSeconds, coefficient: -0.5, qValue: 0.01),           // sleep, strong
        insight(.pressure, coefficient: 0.3, qValue: 0.02),                // weather, strong
        insight(.heartRate, coefficient: 0.15, qValue: 0.30),              // suggestive -> excluded
        insight(.respiratoryRate, coefficient: 0.4, qValue: 0.01, explainedBy: .heartRate) // confounded -> excluded
      ],
      insufficient: [],
      baselines: nil,
      schemaVersion: InsightsReport.currentSchemaVersion,
      enabledFingerprint: nil)

    let profile = report.domainProfile
    XCTAssertEqual(profile.count, 2, "Suggestive and confounded insights are excluded")
    XCTAssertEqual(profile.first?.domain, .sleep, "Strongest |coefficient| domain ranks first")
    XCTAssertEqual(profile.last?.domain, .weather)
  }

  func testRiskPredictionContributionsCodableBackCompat() throws {
    // A prediction with contributions round-trips.
    let withContributions = RiskPrediction(
      input: .empty,
      probability: 0.5,
      topFactors: [],
      computedAt: baseDate,
      contributions: [RiskPrediction.RiskContribution(feature: .sleepSeconds, mlFeatureName: "Sleep Seconds", delta: 0.12)])
    let data = try JSONEncoder().encode(withContributions)
    let decoded = try JSONDecoder().decode(RiskPrediction.self, from: data)
    XCTAssertEqual(decoded.contributions?.first?.delta, 0.12)

    // An older blob without the key decodes to nil (optional-with-default).
    let legacy = RiskPrediction(input: .empty, probability: 0.5, topFactors: [], computedAt: baseDate)
    let legacyData = try JSONEncoder().encode(legacy)
    XCTAssertNil(try JSONDecoder().decode(RiskPrediction.self, from: legacyData).contributions)
  }

  // MARK: Shorter prediction horizon (Phase 4)

  func testShortHorizonLabel() {
    func input(interval: TimeInterval?, outlook: Outlook) -> ModelInput {
      ModelInput(date: baseDate, location: nil, weatherStatistics: nil, healthKitData: nil, timeIntervalUntilNextHeadacheStart: interval, outlook: outlook)
    }

    // Onset in 6h: positive for both horizons.
    let soon = input(interval: 6.0 * 3600.0, outlook: .possibleHeadache)
    XCTAssertTrue(soon.isPositive(horizon: .standard))
    XCTAssertTrue(soon.isPositive(horizon: .short))

    // Onset in 18h: within the 24h window but outside the 12h window.
    let mid = input(interval: 18.0 * 3600.0, outlook: .possibleHeadache)
    XCTAssertTrue(mid.isPositive(horizon: .standard))
    XCTAssertFalse(mid.isPositive(horizon: .short))

    // Onset in 40h: negative for both.
    let far = input(interval: 40.0 * 3600.0, outlook: .noHeadache)
    XCTAssertFalse(far.isPositive(horizon: .standard))
    XCTAssertFalse(far.isPositive(horizon: .short))

    // No upcoming onset, and in-headache rows: never positive.
    XCTAssertFalse(input(interval: nil, outlook: .noHeadache).isPositive(horizon: .short))
    XCTAssertFalse(input(interval: nil, outlook: .headache).isPositive(horizon: .short))
  }

  // MARK: Baseline-relative autonomic features (Phase 2)

  /// Builds a chronologically sorted series carrying one metric.
  private func baselineSeries(_ metric: HealthKitData, _ values: [Double]) -> [ModelInput] {
    return values.enumerated().map { index, value in
      ModelInput(
        date: baseDate.addingTimeInterval(Double(index) * 86_400.0),
        location: nil,
        weatherStatistics: nil,
        healthKitData: [metric: value])
    }
  }

  func testBaselineZScoresAreCausal() {
    let values: [Double] = [10, 10, 12, 8, 10, 10, 11, 9, 10, 10, 10, 30]
    let attached = BaselineFeatures.attachingBaselineFeatures(to: baselineSeries(.restingHeartRate, values))

    // The first five rows have fewer than five trailing samples: no z-score.
    for index in 0 ..< 5 {
      XCTAssertNil(attached[index].baselineZ?[.restingHeartRate], "Row \(index) has too little history")
    }
    // Later rows do get one.
    XCTAssertNotNil(attached[8].baselineZ?[.restingHeartRate])
    // The final spike reads as a strong positive deviation.
    XCTAssertGreaterThan(attached[11].baselineZ?[.restingHeartRate] ?? 0, 2.0)

    // Mutating a FUTURE row must not change an earlier row's z-score or slope
    // — the no-leakage invariant that keeps within-subject validation honest.
    let zAt8 = attached[8].baselineZ?[.restingHeartRate]
    let slopeAt8 = attached[8].baselineSlope?[.restingHeartRate]
    var future = values
    future[11] = 999.0
    future[10] = 999.0
    let reattached = BaselineFeatures.attachingBaselineFeatures(to: baselineSeries(.restingHeartRate, future))
    XCTAssertEqual(reattached[8].baselineZ?[.restingHeartRate], zAt8, "A future value leaked into an earlier row's z")
    XCTAssertEqual(reattached[8].baselineSlope?[.restingHeartRate], slopeAt8, "A future value leaked into an earlier row's slope")
  }

  func testBaselineSlopeSignTracksDailyChange() {
    // Daily samples spaced 24h apart never fall inside the 2–12h slope window,
    // so slopes stay absent; a steady climb should still produce z-scores.
    let attached = BaselineFeatures.attachingBaselineFeatures(to: baselineSeries(.heartRateVariabilitySDNN, [50, 50, 50, 50, 50, 50, 40, 30]))
    XCTAssertNil(attached[7].baselineSlope?[.heartRateVariabilitySDNN], "24h-spaced samples are outside the slope window")
    XCTAssertLessThan(attached[7].baselineZ?[.heartRateVariabilitySDNN] ?? 0, 0.0, "A drop below baseline is a negative z")
  }

  func testBaselineSlopeWithinWindow() {
    // Samples 6h apart do fall in the slope window: a rising then falling
    // series yields a negative slope at the turn.
    let inputs = (0 ..< 8).map { index in
      ModelInput(
        date: baseDate.addingTimeInterval(Double(index) * 6.0 * 3600.0),
        location: nil,
        weatherStatistics: nil,
        healthKitData: [.bodyTemperature: [36.0, 36.1, 36.2, 36.3, 36.4, 36.5, 36.6, 36.0][index]])
    }
    let attached = BaselineFeatures.attachingBaselineFeatures(to: inputs)
    // The final row drops sharply versus ~6h earlier: negative slope.
    XCTAssertLessThan(attached[7].baselineSlope?[.bodyTemperature] ?? 0, 0.0)
  }

  func testFeatureBaselinesInferenceZScore() {
    // Seven daily samples: mean 11, population std 2.
    let inputs = baselineSeries(.bodyTemperature, [8, 9, 10, 11, 12, 13, 14])
    let baselines = FeatureBaselines.computed(from: inputs)

    let baseline = baselines.byMetric[.bodyTemperature]
    XCTAssertEqual(baseline?.mean ?? 0, 11.0, accuracy: 1e-9)
    XCTAssertEqual(baseline?.std ?? 0, 2.0, accuracy: 1e-9)

    // (15 - 11) / 2 = 2.0.
    XCTAssertEqual(baselines.zScores(for: [.bodyTemperature: 15.0])[.bodyTemperature] ?? 0, 2.0, accuracy: 1e-9)
    // Winsorized at ±6.
    XCTAssertEqual(baselines.zScores(for: [.bodyTemperature: 1000.0])[.bodyTemperature] ?? 0, 6.0, accuracy: 1e-9)
    XCTAssertEqual(baselines.zScores(for: [.bodyTemperature: -1000.0])[.bodyTemperature] ?? 0, -6.0, accuracy: 1e-9)
    // A metric with no baseline yields no z-score.
    XCTAssertNil(baselines.zScores(for: [.heartRate: 60.0])[.heartRate])
  }

  func testBaselineProviderDefaultsMissingToZero() {
    // A value of 0 means "at baseline" / "no change", so a missing feature is
    // a valid neutral 0.
    let provider = AutonomicBaselineInput(baselineZ: [.restingHeartRate: 1.5], baselineSlope: [.restingHeartRate: -0.5])
    XCTAssertEqual(provider.featureValue(for: AutonomicBaselineInput.FeatureName.restingHeartRate)?.doubleValue, 1.5)
    XCTAssertEqual(provider.featureValue(for: AutonomicBaselineInput.FeatureName.restingHeartRateSlope)?.doubleValue, -0.5)
    XCTAssertEqual(provider.featureValue(for: AutonomicBaselineInput.FeatureName.hrv)?.doubleValue, 0.0)
    XCTAssertEqual(provider.featureValue(for: AutonomicBaselineInput.FeatureName.hrvSlope)?.doubleValue, 0.0)
  }

  func testHRVTimeDomain() {
    // RMSSD = sqrt(mean(diff^2)); diffs are ±50 -> 50.
    XCTAssertEqual(HRVCalculator.rmssd(segments: [[800, 850, 800, 850]]) ?? 0, 50.0, accuracy: 1e-9)
    // pNN50 counts |diff| > 50 ms.
    XCTAssertEqual(HRVCalculator.pnn50(segments: [[800, 860, 800]]) ?? -1, 1.0, accuracy: 1e-9)
    XCTAssertEqual(HRVCalculator.pnn50(segments: [[800, 840, 800]]) ?? -1, 0.0, accuracy: 1e-9)
    // Pools successive differences across segments, within each segment only.
    XCTAssertEqual(HRVCalculator.rmssd(segments: [[800, 850], [800, 850]]) ?? 0, 50.0, accuracy: 1e-9)
    // No successive pair -> nil.
    XCTAssertNil(HRVCalculator.rmssd(segments: [[800]]))
    // Too few beats for a spectrum -> nil.
    XCTAssertNil(HRVCalculator.lfhf(segments: [[800, 810]]))
  }

  func testHRVFrequencyBandDominance() {
    func segment(frequency: Double) -> [Double] {
      var intervals = [Double]()
      var time = 0.0
      for _ in 0 ..< 120 {
        let interval = 800.0 + 40.0 * sin(2.0 * Double.pi * frequency * time)
        intervals.append(interval)
        time += interval / 1000.0
      }
      return intervals
    }

    // A 0.25 Hz oscillation lives in the HF band -> LF/HF < 1.
    let hfDominant = HRVCalculator.lfhf(segments: [segment(frequency: 0.25)])
    XCTAssertNotNil(hfDominant)
    XCTAssertLessThan(hfDominant ?? 99, 1.0)

    // A 0.09 Hz oscillation lives in the LF band -> LF/HF > 1.
    let lfDominant = HRVCalculator.lfhf(segments: [segment(frequency: 0.09)])
    XCTAssertNotNil(lfDominant)
    XCTAssertGreaterThan(lfDominant ?? 0, 1.0)
  }

  func testInferenceSlopeFromPreviousReading() {
    // Baseline: mean 11, std 2 (seven daily samples).
    let baselines = FeatureBaselines.computed(from: baselineSeries(.bodyTemperature, [8, 9, 10, 11, 12, 13, 14]))
    // Current 15 -> z 2.0; previous 13 -> z 1.0; slope = 1.0.
    let slopes = baselines.slopes(current: [.bodyTemperature: 15.0], previous: [.bodyTemperature: 13.0])
    XCTAssertEqual(slopes[.bodyTemperature] ?? 0, 1.0, accuracy: 1e-9)
    // No previous reading -> no slope.
    XCTAssertTrue(baselines.slopes(current: [.bodyTemperature: 15.0], previous: nil).isEmpty)
  }

}
