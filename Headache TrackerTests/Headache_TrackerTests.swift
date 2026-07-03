//
//  Headache_TrackerTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
import DataController
import HealthKit
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
      exposureCount: 0,
      insights: [insight],
      insufficient: [],
      baselines: [.sleepSeconds: FeatureBaseline(mean: 7.0 * 3_600.0, std: 3_600.0, count: 14)],
      schemaVersion: InsightsReport.currentSchemaVersion)

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
    // schemaVersion, no exposureCount, insights without the new fields.
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
    trainingData.updateWithHealthKitData([.dietaryCaffeine: 200.0, .appleExerciseTime: 20.0], at: baseDate)

    let sample = trainingData.correlationSample
    XCTAssertEqual(sample?.values[.dietaryCaffeine], 200.0)
    XCTAssertEqual(sample?.values[.exerciseMinutes], 20.0)
  }

  func testExposureMergeCountsTrailingWindow() {
    let samples = (0 ..< 4).map { day in
      CorrelationSample(timestamp: baseDate.addingTimeInterval(Double(day) * 86_400.0), values: [:])
    }

    // One caffeine exposure at noon of day 1 (relative to samples at baseDate + n days).
    let exposures = [
      ExposureEvent(kind: "caffeine", timestamp: baseDate.addingTimeInterval(86_400.0 - 3_600.0), amount: nil),
      ExposureEvent(kind: "caffeine", timestamp: baseDate.addingTimeInterval(86_400.0 - 7_200.0), amount: nil),
      ExposureEvent(kind: "custom-thing", timestamp: baseDate.addingTimeInterval(86_400.0), amount: nil)
    ]

    let merged = CorrelationEngine.merged(samples, exposures: exposures)

    // Day 0 precedes the first check-in: untouched.
    XCTAssertNil(merged[0].values[.exposureCaffeine])
    // Day 1 sees both events in its trailing 24h.
    XCTAssertEqual(merged[1].values[.exposureCaffeine], 2.0)
    // Day 2 sees none (events are >24h old).
    XCTAssertEqual(merged[2].values[.exposureCaffeine], 0.0)
    // Custom kinds never become features.
    for sample in merged {
      XCTAssertFalse(sample.values.keys.contains(where: { $0 == .exposureScreenTime }))
    }
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

  func testExposureEventsExtraction() throws {
    let exposure = Exposure(context: context)
    exposure.identifier = UUID()
    exposure.kindRaw = "alcohol"
    exposure.timestamp = baseDate
    exposure.amount = 0.0

    let events = try HeadacheManager.exposureEvents(in: context)
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.kind, "alcohol")
    XCTAssertNil(events.first?.amount, "Zero amount reads as no amount")
  }


}
