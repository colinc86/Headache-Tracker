//
//  RiskSnapshotTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the widget snapshot's derivations.
final class RiskSnapshotTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  private func prediction(probability: Double = 0.42, short: Double? = 0.31, computedAt: Date? = nil, contributions: [RiskPrediction.RiskContribution]? = nil, topFactors: [RiskPrediction.RiskFactor] = []) -> RiskPrediction {
    var prediction = RiskPrediction(input: Previewing.Prediction.input, probability: probability, topFactors: topFactors, computedAt: computedAt ?? now)
    prediction.shortProbability = short
    prediction.contributions = contributions
    return prediction
  }

  private func point(hoursAgo: Double, probability: Double) -> HeadacheManager.RiskHistoryPoint {
    return HeadacheManager.RiskHistoryPoint(date: now.addingTimeInterval(-hoursAgo * 3600.0), probability: probability)
  }

  private func snapshot(_ risk: RiskPrediction?, severity: Headache.Severity? = nil, start: Date? = nil, history: [HeadacheManager.RiskHistoryPoint] = [], report: InsightsReport? = nil, asOf: Date? = nil) -> RiskSnapshot {
    return RiskSnapshot(risk: risk, currentSeverity: severity, headacheStart: start, history: history, report: report, asOf: asOf ?? now)
  }

  // MARK: Empty and freshness

  func testEmptyRiskProducesEmptySnapshot() {
    for risk in [nil, RiskPrediction.empty, prediction(probability: -1.0)] {
      let empty = snapshot(risk)
      XCTAssertTrue(empty.isEmpty)
      XCTAssertNil(empty.computedAt, "the empty sentinel's epoch date must never read as an age")
      XCTAssertNil(empty.age)
      XCTAssertEqual(empty.freshness, .none)
      XCTAssertTrue(empty.signals.isEmpty)
      XCTAssertNil(empty.brief)
      XCTAssertNil(empty.trajectory)
      XCTAssertNil(empty.peakWindow)
      XCTAssertEqual(empty.peakWindowText, "Across the next 24 hours")
    }
  }

  func testFreshnessThresholds() {
    XCTAssertEqual(RiskSnapshot.freshness(forAge: 89.0 * 60.0), .fresh)
    XCTAssertEqual(RiskSnapshot.freshness(forAge: 91.0 * 60.0), .aging)
    XCTAssertEqual(RiskSnapshot.freshness(forAge: 5.0 * 3600.0 + 59.0 * 60.0), .aging)
    XCTAssertEqual(RiskSnapshot.freshness(forAge: 6.0 * 3600.0 + 60.0), .stale)
    XCTAssertEqual(RiskSnapshot.freshness(forAge: -300.0), .fresh, "clock skew counts as fresh")

    let fresh = snapshot(prediction(computedAt: now.addingTimeInterval(-20.0 * 60.0)))
    XCTAssertEqual(fresh.freshness, .fresh)
    XCTAssertEqual(fresh.age ?? 0.0, 20.0 * 60.0, accuracy: 0.5)
    XCTAssertFalse(fresh.isStale)
  }

  func testAdvancedReagesWithoutChangingData() {
    let fresh = snapshot(prediction(computedAt: now.addingTimeInterval(-20.0 * 60.0)))
    let later = fresh.advanced(to: now.addingTimeInterval(8.0 * 3600.0))
    XCTAssertTrue(later.isStale)
    XCTAssertEqual(later.probability24, fresh.probability24)
    XCTAssertEqual(later.signals, fresh.signals)
    XCTAssertEqual(later.history, fresh.history)
    XCTAssertEqual(later.asOf, now.addingTimeInterval(8.0 * 3600.0))
    XCTAssertTrue(later.asPlaceholder().isPlaceholder)
    XCTAssertFalse(later.isPlaceholder)
  }

  // MARK: History

  func testHistoryAppendsLiveForecastWhenNewer() {
    let older = [point(hoursAgo: 2.0, probability: 0.2), point(hoursAgo: 1.0, probability: 0.3)]
    let appended = snapshot(prediction(computedAt: now), history: older.reversed())
    XCTAssertEqual(appended.history.count, 3)
    XCTAssertEqual(appended.history.last?.probability, 0.42)
    XCTAssertEqual(appended.history.map({ $0.date }), appended.history.map({ $0.date }).sorted(), "sorted ascending")

    // A point within a minute of the forecast is the forecast's own row.
    let recent = older + [point(hoursAgo: 30.0 / 3600.0, probability: 0.42)]
    XCTAssertEqual(snapshot(prediction(computedAt: now), history: recent).history.count, 3)

    // Negative (empty) probabilities are dropped.
    XCTAssertEqual(snapshot(prediction(computedAt: now), history: [point(hoursAgo: 3.0, probability: -1.0)]).history.count, 1)
  }

  // MARK: Trajectory and peak window

  func testTrajectoryRule() {
    let flat = [point(hoursAgo: 2.0, probability: 0.40), point(hoursAgo: 4.0, probability: 0.40)]
    XCTAssertEqual(RiskSnapshot.trajectory(probability: 0.48, computedAt: now, history: flat), .rising)
    XCTAssertEqual(RiskSnapshot.trajectory(probability: 0.479, computedAt: now, history: flat), .steady)
    XCTAssertEqual(RiskSnapshot.trajectory(probability: 0.32, computedAt: now, history: flat), .falling)
    XCTAssertEqual(RiskSnapshot.trajectory(probability: 0.321, computedAt: now, history: flat), .steady)

    // Points inside the last hour or older than six hours are ignored.
    let outside = [point(hoursAgo: 0.5, probability: 0.9), point(hoursAgo: 7.0, probability: 0.9), point(hoursAgo: 3.0, probability: 0.4)]
    XCTAssertNil(RiskSnapshot.trajectory(probability: 0.6, computedAt: now, history: outside), "one reference point is not enough")

    // The median resists a single spike.
    let spiky = [point(hoursAgo: 2.0, probability: 0.40), point(hoursAgo: 3.0, probability: 0.95), point(hoursAgo: 4.0, probability: 0.41)]
    XCTAssertEqual(RiskSnapshot.trajectory(probability: 0.50, computedAt: now, history: spiky), .rising)

    let rising = snapshot(prediction(probability: 0.6, computedAt: now), history: flat)
    XCTAssertEqual(rising.trajectory, .rising)
  }

  func testPeakWindowRule() {
    XCTAssertEqual(RiskSnapshot.peakWindow(probability24: 0.40, probability12: 0.30), .frontLoaded)
    XCTAssertEqual(RiskSnapshot.peakWindow(probability24: 0.40, probability12: 0.299), .spread)
    XCTAssertEqual(RiskSnapshot.peakWindow(probability24: 0.40, probability12: 0.16), .building)
    XCTAssertEqual(RiskSnapshot.peakWindow(probability24: 0.40, probability12: 0.161), .spread)
    XCTAssertNil(RiskSnapshot.peakWindow(probability24: 0.40, probability12: nil))
    XCTAssertNil(RiskSnapshot.peakWindow(probability24: 0.0, probability12: 0.0))

    XCTAssertEqual(snapshot(prediction(probability: 0.42, short: 0.35)).peakWindowText, "Mostly in the next 12 hours")
    XCTAssertEqual(snapshot(prediction(probability: 0.42, short: 0.25)).peakWindowText, "Spread across the day")
    XCTAssertEqual(snapshot(prediction(probability: 0.42, short: 0.10)).peakWindowText, "Building through tomorrow")
    let flat = [point(hoursAgo: 2.0, probability: 0.60), point(hoursAgo: 4.0, probability: 0.60)]
    XCTAssertEqual(snapshot(prediction(probability: 0.42, short: nil), history: flat).peakWindowText, "Easing through tomorrow")
  }

  // MARK: Signals and state

  func testSignalsPreferContributionsThenTopFactors() {
    let contributions = [
      RiskPrediction.RiskContribution(feature: .restingHeartRate, mlFeatureName: "Resting Heart Rate", delta: -0.03),
      RiskPrediction.RiskContribution(feature: .sleepSeconds, mlFeatureName: "Sleep Seconds", delta: 0.11),
      RiskPrediction.RiskContribution(feature: nil, mlFeatureName: "Weekday Sin", delta: 0.05),
    ]
    let baselines: [CorrelationFeature: FeatureBaseline] = [.sleepSeconds: FeatureBaseline(mean: 7.0 * 3600.0, std: 1800.0, count: 10)]
    let report = InsightsReport(generatedAt: now, rowCount: 10, insights: [], insufficient: [], baselines: baselines, schemaVersion: InsightsReport.currentSchemaVersion, enabledFingerprint: nil)

    let signed = snapshot(prediction(contributions: contributions), report: report)
    XCTAssertTrue(signed.hasSignedSignals)
    XCTAssertEqual(signed.signals.map({ $0.mlFeatureName }), ["Sleep Seconds", "Weekday Sin", "Resting Heart Rate"], "ordered by magnitude")
    XCTAssertEqual(signed.raising.count, 2)
    XCTAssertEqual(signed.easing.count, 1)
    XCTAssertEqual(signed.signals[0].todayValue, 5.2 * 3600.0, "today's value comes from the forecast's input")
    XCTAssertEqual(signed.signals[0].baselineMean, 7.0 * 3600.0)
    XCTAssertNotNil(signed.signals[0].todayVersusUsual)
    XCTAssertNil(signed.signals[1].feature)
    XCTAssertEqual(signed.signals[1].systemImage, "waveform.path.ecg")
    XCTAssertNil(signed.signals[1].todayVersusUsual)

    let factors = [
      RiskPrediction.RiskFactor(feature: .sleepSeconds, mlFeatureName: "Sleep Seconds", direction: .reduced, contributionDescription: ""),
      RiskPrediction.RiskFactor(feature: .sigmaPressure, mlFeatureName: "Sigma Pressure", direction: .elevated, contributionDescription: ""),
    ]
    let unsigned = snapshot(prediction(contributions: [], topFactors: factors))
    XCTAssertFalse(unsigned.hasSignedSignals)
    XCTAssertEqual(unsigned.signals.count, 2)
    XCTAssertFalse(unsigned.signals[0].isRaising)
    XCTAssertTrue(unsigned.signals[1].isRaising)
  }

  func testActiveHeadacheRequiresPresentSeverity() {
    let start = now.addingTimeInterval(-3600.0)
    XCTAssertNil(snapshot(prediction(), severity: nil, start: start).activeHeadache)
    XCTAssertNil(snapshot(prediction(), severity: .notPresent, start: start).activeHeadache)
    let active = snapshot(prediction(), severity: .moderate, start: start)
    XCTAssertEqual(active.activeHeadache?.severity, .moderate)
    XCTAssertEqual(active.activeHeadache?.start, start)
    XCTAssertEqual(active.probability24, 0.42, "the forecast rides along")
    XCTAssertNotNil(snapshot(nil, severity: .mild, start: nil).activeHeadache, "an active headache needs no forecast")
  }

  // MARK: Samples

  func testSamplesAreDeterministicAndDistinct() {
    let a = RiskSnapshot.Samples.elevated(asOf: now)
    let b = RiskSnapshot.Samples.elevated(asOf: now)
    XCTAssertEqual(a, b)
    XCTAssertEqual(a.history.count, 48)
    XCTAssertEqual(a.history.last?.probability ?? 0.0, 0.42, accuracy: 1e-9, "the history flows into the forecast")
    XCTAssertEqual(a.freshness, .fresh)
    XCTAssertEqual(RiskSnapshot.Samples.high(asOf: now).tier24, .high)
    XCTAssertEqual(RiskSnapshot.Samples.low(asOf: now).tier12, .low)
    XCTAssertTrue(RiskSnapshot.Samples.stale(asOf: now).isStale)
    XCTAssertNotNil(RiskSnapshot.Samples.activeHeadache(asOf: now).activeHeadache)
    XCTAssertTrue(RiskSnapshot.Samples.empty(asOf: now).isEmpty)
    XCTAssertTrue(RiskSnapshot.Samples.placeholder(asOf: now).isPlaceholder)
    for point in a.history {
      XCTAssertGreaterThan(point.probability, 0.0)
      XCTAssertLessThan(point.probability, 1.0)
    }
  }

}
