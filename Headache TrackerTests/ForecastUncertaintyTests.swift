//
//  ForecastUncertaintyTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 10/3/26.
//

import XCTest
@testable import Headache_Tracker

/// The pure math behind the forecast's range, coverage, and grade, plus the
/// Codable back-compat of the fields that carry them.
final class ForecastUncertaintyTests: XCTestCase {

  // MARK: Interval

  func testIntervalSpansTheMemberPercentiles() throws {
    let members = [0.40, 0.44, 0.48, 0.52, 0.56, 0.60]
    let interval = try XCTUnwrap(ForecastUncertainty.interval(point: 0.50, members: members))
    XCTAssertEqual(interval.lower, ClassificationMetrics.percentile(members, 0.10), accuracy: 1e-9)
    XCTAssertEqual(interval.upper, ClassificationMetrics.percentile(members, 0.90), accuracy: 1e-9)
    XCTAssertTrue(interval.contains(0.50))
  }

  func testIntervalWidensToIncludeThePoint() throws {
    let interval = try XCTUnwrap(ForecastUncertainty.interval(point: 0.70, members: [0.40, 0.42, 0.44, 0.46]))
    XCTAssertEqual(interval.upper, 0.70, accuracy: 1e-9)
    XCTAssertEqual(interval.lower, ClassificationMetrics.percentile([0.40, 0.42, 0.44, 0.46], 0.10), accuracy: 1e-9)
  }

  func testIntervalClampsToProbabilities() throws {
    let interval = try XCTUnwrap(ForecastUncertainty.interval(point: 1.2, members: [-0.2, -0.1, 0.5, 1.2, 1.3]))
    XCTAssertEqual(interval.lower, 0.0)
    XCTAssertEqual(interval.upper, 1.0)
  }

  func testIntervalNeedsEnoughMembers() {
    XCTAssertNil(ForecastUncertainty.interval(point: 0.5, members: []))
    XCTAssertNil(ForecastUncertainty.interval(point: 0.5, members: [0.4, 0.6]))
    XCTAssertNotNil(ForecastUncertainty.interval(point: 0.5, members: [0.4, 0.5, 0.6]))
  }

  func testIntervalOrdersItsBoundsAndFormats() {
    let interval = RiskInterval(lower: 0.664, upper: 0.436)
    XCTAssertEqual(interval.lower, 0.436)
    XCTAssertEqual(interval.upper, 0.664)
    XCTAssertEqual(interval.rangeText, "44–66%")
    XCTAssertEqual(interval.spokenText, "likely between 44 and 66 percent")
    XCTAssertEqual(interval.width, 0.228, accuracy: 1e-9)
  }

  // MARK: Confidence

  func testConfidenceGradesOnWidthAndCoverage() {
    let full = InputCoverage(presentSignals: 11, expectedSignals: 11)
    let partial = InputCoverage(presentSignals: 7, expectedSignals: 11)
    let half = InputCoverage(presentSignals: 5, expectedSignals: 11)

    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.40, upper: 0.55), coverage: full), .steady)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.40, upper: 0.551), coverage: full), .fair)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.40, upper: 0.55), coverage: partial), .fair)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.30, upper: 0.60), coverage: full), .fair)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.30, upper: 0.601), coverage: full), .rough)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: RiskInterval(lower: 0.40, upper: 0.55), coverage: half), .rough)
  }

  func testConfidenceWithoutARangeNeverReadsSteady() {
    XCTAssertEqual(ForecastUncertainty.confidence(interval: nil, coverage: InputCoverage(presentSignals: 11, expectedSignals: 11)), .fair)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: nil, coverage: InputCoverage(presentSignals: 5, expectedSignals: 11)), .rough)
    XCTAssertEqual(ForecastUncertainty.confidence(interval: nil, coverage: nil), .fair)
  }

  func testSamplesGradeAsIntended() {
    XCTAssertEqual(RiskSnapshot.Samples.low().confidence, .steady)
    XCTAssertEqual(RiskSnapshot.Samples.elevated().confidence, .fair)
    XCTAssertEqual(RiskSnapshot.Samples.high().confidence, .rough)
    XCTAssertNil(RiskSnapshot.Samples.empty().interval24)
  }

  // MARK: Accuracy

  func testHeadlineAccuracyPrefersEnoughObservedForecasts() throws {
    let observed = try XCTUnwrap(ForecastAccuracy.headline(observedAccuracy: 0.68, observedCount: 30, outOfFold: 0.71))
    XCTAssertEqual(observed.source, .observed)
    XCTAssertEqual(observed.value, 0.68)
    XCTAssertEqual(observed.count, 30)
    XCTAssertEqual(observed.text, "68% accurate")
    XCTAssertEqual(observed.spokenText, "68 percent accurate")

    let fallback = try XCTUnwrap(ForecastAccuracy.headline(observedAccuracy: 0.68, observedCount: 29, outOfFold: 0.71))
    XCTAssertEqual(fallback.source, .outOfFold)
    XCTAssertEqual(fallback.value, 0.71)

    XCTAssertNil(ForecastAccuracy.headline(observedAccuracy: 0.68, observedCount: 29, outOfFold: nil))
    XCTAssertNil(ForecastAccuracy.headline(observedAccuracy: nil, observedCount: 0, outOfFold: nil))
  }

  func testSnapshotHeadlineAccuracyFallsBackToTheForecastsModelAccuracy() throws {
    let fromModel = RiskSnapshot.Samples.elevated()
    XCTAssertEqual(fromModel.accuracy, ForecastAccuracy(value: 0.71, source: .outOfFold, count: 0))

    var prediction = Previewing.Prediction.prediction
    prediction.modelAccuracy = nil
    let none = RiskSnapshot(risk: prediction, currentSeverity: nil, headacheStart: nil, history: [], report: nil)
    XCTAssertNil(none.accuracy)

    let observed = RiskSnapshot(risk: prediction, currentSeverity: nil, headacheStart: nil, history: [], report: nil, observedAccuracy: (0.64, 40))
    XCTAssertEqual(observed.accuracy?.source, .observed)
    XCTAssertEqual(observed.advanced(to: Date().addingTimeInterval(3600.0)).accuracy, observed.accuracy)
  }

  // MARK: Coverage

  func testCoverageCountsExpectedSignalsAndWeather() {
    var medians = FeatureMedians()
    medians.healthKit = [.sleepSeconds: 7.0 * 3600.0, .heartRateVariabilitySDNN: 45.0, .restingHeartRate: 60.0, .dietaryCaffeine: 120.0]
    medians.pressure = 101.3
    medians.humidity = 0.5
    medians.temperature = 20.0

    var input = Previewing.Prediction.input
    input.healthKitData = [.sleepSeconds: 6.0 * 3600.0, .restingHeartRate: 58.0]

    let coverage = medians.coverage(of: input, enabled: { $0 != .dietaryCaffeine })
    XCTAssertEqual(coverage.expectedSignals, 4, "three enabled metrics plus weather")
    XCTAssertEqual(coverage.presentSignals, 3, "two metrics plus weather")
    XCTAssertEqual(coverage.imputedSignals, 1)
    XCTAssertEqual(coverage.fraction, 0.75, accuracy: 1e-9)
    XCTAssertEqual(coverage.summary, "3 of 4 signals")

    input.weatherStatistics = nil
    XCTAssertEqual(medians.coverage(of: input, enabled: { _ in true }).presentSignals, 2)
    XCTAssertEqual(medians.coverage(of: input, enabled: { _ in true }).expectedSignals, 5)
  }

  func testCoverageWithNothingExpectedIsFull() {
    let coverage = FeatureMedians().coverage(of: .empty, enabled: { _ in true })
    XCTAssertEqual(coverage.expectedSignals, 0)
    XCTAssertEqual(coverage.fraction, 1.0)
    XCTAssertEqual(coverage.imputedSignals, 0)
  }

  // MARK: Resampling

  func testClusterResamplesAreDeterministicAndKeepClustersWhole() {
    let clusters = (0 ..< 12).map({ AnyHashable($0 / 3) })
    let first = ClassificationMetrics.clusterResamples(clusters: clusters, resamples: 6, seed: 7)
    let second = ClassificationMetrics.clusterResamples(clusters: clusters, resamples: 6, seed: 7)
    XCTAssertEqual(first, second)
    XCTAssertEqual(first.count, 6)
    for resample in first {
      XCTAssertEqual(resample.count % 3, 0, "each draw is a whole cluster of three rows")
      XCTAssertEqual(resample.count, 12, "as many clusters as exist")
    }
    XCTAssertNotEqual(first, ClassificationMetrics.clusterResamples(clusters: clusters, resamples: 6, seed: 8))
    XCTAssertTrue(ClassificationMetrics.clusterResamples(clusters: [AnyHashable(1), AnyHashable(1)], resamples: 3, seed: 1).isEmpty)
  }

  func testLabelClusterSharesOnsetsAndSplitsTheTailByDay() throws {
    let calendar = Calendar(identifier: .gregorian)
    let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 6)))

    var early = Previewing.Prediction.input
    early.date = start
    early.timeIntervalUntilNextHeadacheStart = 10.0 * 3600.0
    var later = early
    later.date = start.addingTimeInterval(4.0 * 3600.0)
    later.timeIntervalUntilNextHeadacheStart = 6.0 * 3600.0
    XCTAssertEqual(early.labelCluster(calendar: calendar), later.labelCluster(calendar: calendar), "rows before the same onset share its date")

    var tailMorning = early
    tailMorning.timeIntervalUntilNextHeadacheStart = nil
    var tailEvening = tailMorning
    tailEvening.date = start.addingTimeInterval(12.0 * 3600.0)
    var tailTomorrow = tailMorning
    tailTomorrow.date = start.addingTimeInterval(24.0 * 3600.0)
    XCTAssertEqual(tailMorning.labelCluster(calendar: calendar), tailEvening.labelCluster(calendar: calendar))
    XCTAssertNotEqual(tailMorning.labelCluster(calendar: calendar), tailTomorrow.labelCluster(calendar: calendar))
    XCTAssertEqual(tailMorning.labelCluster(calendar: calendar), calendar.startOfDay(for: start))
  }

  // MARK: Codable

  func testRiskPredictionDecodesWithoutRangeFields() throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(Previewing.Prediction.prediction)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertNotNil(object["interval"])
    XCTAssertNotNil(object["coverage"])
    object.removeValue(forKey: "interval")
    object.removeValue(forKey: "coverage")
    object.removeValue(forKey: "modelAccuracy")

    let old = try JSONDecoder().decode(RiskPrediction.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(old.interval)
    XCTAssertNil(old.coverage)
    XCTAssertNil(old.modelAccuracy)
    XCTAssertEqual(old.probability, 0.42)
    XCTAssertEqual(old.confidence, .fair)

    let roundTrip = try JSONDecoder().decode(RiskPrediction.self, from: data)
    XCTAssertEqual(roundTrip.interval, RiskInterval(lower: 0.33, upper: 0.52))
    XCTAssertEqual(roundTrip.coverage, InputCoverage(presentSignals: 9, expectedSignals: 11))
    XCTAssertEqual(roundTrip, Previewing.Prediction.prediction)
  }

  func testRiskPredictionEqualityNoticesTheRange() {
    var changed = Previewing.Prediction.prediction
    XCTAssertEqual(changed, Previewing.Prediction.prediction)
    changed.interval = RiskInterval(lower: 0.20, upper: 0.70)
    XCTAssertNotEqual(changed, Previewing.Prediction.prediction)
  }

  func testModelMetricsDecodesWithoutProvenanceFields() throws {
    let json = """
    {"trainedAt": 0, "accuracy": 0.7, "brier": 0.2, "calibrationBuckets": [], "trainingRowCount": 100, "validationRowCount": 20, "positiveCount": 5, "isCalibrated": true}
    """
    let metrics = try JSONDecoder().decode(ModelMetrics.self, from: Data(json.utf8))
    XCTAssertNil(metrics.trainingDayCount)
    XCTAssertNil(metrics.episodeCount)
    XCTAssertNil(metrics.ensembleMemberCount)
    XCTAssertNil(metrics.provenanceSummary)

    var full = metrics
    full.trainingDayCount = 61
    full.episodeCount = 1
    XCTAssertEqual(full.provenanceSummary, "Based on 61 days and 1 headache")
  }

  // MARK: Snapshot

  func testSnapshotCarriesTheRangeThroughAdvancing() {
    let snapshot = RiskSnapshot.Samples.elevated()
    XCTAssertEqual(snapshot.interval24, RiskSnapshot.Samples.fairElevated.interval)
    XCTAssertEqual(snapshot.coverage, RiskSnapshot.Samples.fairElevated.coverage)
    let later = snapshot.advanced(to: Date().addingTimeInterval(3.0 * 3600.0))
    XCTAssertEqual(later.interval24, snapshot.interval24)
    XCTAssertEqual(later.coverage, snapshot.coverage)
    XCTAssertEqual(later.confidence, .fair)
  }

  // MARK: Stub

  func testStubScoresCarryAnIntervalOnRequest() async throws {
    let predictor = Predictor()
    let input = Previewing.Prediction.input
    let plain = try await predictor.scores(for: [input]).first
    XCTAssertNil(plain?.interval24)

    let withInterval = try await predictor.scores(for: [input], includeInterval: true)
    let scored = try XCTUnwrap(withInterval.first)
    let interval = try XCTUnwrap(scored.interval24)
    XCTAssertTrue(interval.contains(scored.probability24))
    XCTAssertGreaterThan(interval.width, 0.0)
  }

}
