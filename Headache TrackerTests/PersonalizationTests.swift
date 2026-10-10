//
//  PersonalizationTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the candidate-and-promote personalization rules.
final class PersonalizationTests: XCTestCase {

  private func insight(_ feature: CorrelationFeature, target: TriggerInsight.Target = .occurrence, coefficient: Double, qValue: Double, explainedBy: CorrelationFeature? = nil) -> TriggerInsight {
    return TriggerInsight(
      feature: feature,
      target: target,
      coefficient: coefficient,
      qValue: qValue,
      bestLagHours: target == .occurrence ? 24 : nil,
      lagProfile: [:],
      sampleCount: 100,
      eventCount: 20,
      positiveMean: 1.0,
      baselineMean: 0.0,
      usesBaselineRelative: true,
      explainedBy: explainedBy,
      partialCoefficient: nil)
  }

  private func report(_ insights: [TriggerInsight]) -> InsightsReport {
    return InsightsReport(generatedAt: Date(), rowCount: 100, insights: insights, insufficient: [], baselines: nil, schemaVersion: InsightsReport.currentSchemaVersion, enabledFingerprint: nil)
  }

  private func result(auc: Double?, brier: Double?, usable: Bool = true) -> RollingOriginResult {
    return RollingOriginResult(
      computedAt: Date(),
      horizonHours: 24,
      variant: "test",
      folds: [],
      predictions: [],
      auc: auc,
      aucInterval: nil,
      brier: brier,
      logLoss: nil,
      positiveCount: usable ? 20 : 3,
      negativeCount: usable ? 80 : 3,
      clusterCount: usable ? 6 : 1)
  }

  func testCandidatesFilterRankAndCap() {
    let modelled = PersonalizationSelection.modelledFeatures()
    XCTAssertTrue(modelled.contains(.heartRate))
    XCTAssertTrue(modelled.contains(.pressure))
    XCTAssertFalse(modelled.contains(.sleepSeconds), "sleep has no window column")

    let insights = [
      insight(.heartRate, coefficient: 0.20, qValue: 0.01),                           // strong
      insight(.restingHeartRate, coefficient: -0.35, qValue: 0.10),                   // moderate, strongest
      insight(.respiratoryRate, coefficient: 0.30, qValue: 0.40),                     // suggestive → out
      insight(.bodyTemperature, coefficient: 0.25, qValue: 0.02, explainedBy: .heartRate), // confounded → out
      insight(.sleepSeconds, coefficient: 0.50, qValue: 0.001),                       // not modelled → out
      insight(.pressure, target: .severity, coefficient: 0.40, qValue: 0.001),        // severity → out
      insight(.pressure, coefficient: 0.15, qValue: 0.12),
      insight(.humidity, coefficient: 0.14, qValue: 0.12),
      insight(.temperature, coefficient: 0.13, qValue: 0.12),
      insight(.stepCount, coefficient: 0.12, qValue: 0.12),
      insight(.oxygenSaturation, coefficient: 0.11, qValue: 0.12),
    ]
    let candidates = PersonalizationSelection.candidates(from: report(insights), modelled: modelled)
    XCTAssertEqual(candidates.count, PersonalizationSelection.maximumCandidates)
    XCTAssertEqual(candidates.first, .restingHeartRate)
    XCTAssertEqual(candidates[1], .heartRate)
    XCTAssertFalse(candidates.contains(.respiratoryRate))
    XCTAssertFalse(candidates.contains(.bodyTemperature))
    XCTAssertFalse(candidates.contains(.sleepSeconds))
    XCTAssertFalse(candidates.contains(.oxygenSaturation), "capped at five")
    XCTAssertTrue(PersonalizationSelection.candidates(from: report([]), modelled: modelled).isEmpty)
  }

  func testDecidePromotesOnlyWithMarginBrierAndQuantile() {
    let base = result(auc: 0.60, brier: 0.150)
    let features: [CorrelationFeature] = [.heartRate]
    let positiveSamples = [Double](repeating: 0.03, count: 50)
    let mixedSamples = (0 ..< 50).map({ Double($0 % 2 == 0 ? 0.05 : -0.05) })

    // Wins by margin with a supportive bootstrap.
    let win = PersonalizationSelection.decide(features: features, base: base, personalized: result(auc: 0.64, brier: 0.148), deltaSamples: positiveSamples, previous: nil)
    XCTAssertTrue(win.promoted)
    XCTAssertEqual(win.activeFeatures, [.heartRate])
    XCTAssertTrue(win.statusDescription.hasPrefix("Promoted"))

    // Margin too small.
    XCTAssertFalse(PersonalizationSelection.decide(features: features, base: base, personalized: result(auc: 0.61, brier: 0.148), deltaSamples: positiveSamples, previous: nil).promoted)

    // Brier got worse.
    XCTAssertFalse(PersonalizationSelection.decide(features: features, base: base, personalized: result(auc: 0.64, brier: 0.170), deltaSamples: positiveSamples, previous: nil).promoted)

    // The bootstrap doesn't support it.
    XCTAssertFalse(PersonalizationSelection.decide(features: features, base: base, personalized: result(auc: 0.64, brier: 0.148), deltaSamples: mixedSamples, previous: nil).promoted)

    // Unusable pools or no candidates never promote.
    XCTAssertFalse(PersonalizationSelection.decide(features: features, base: result(auc: 0.6, brier: 0.15, usable: false), personalized: result(auc: 0.7, brier: 0.14), deltaSamples: positiveSamples, previous: nil).promoted)
    let none = PersonalizationSelection.decide(features: [], base: base, personalized: base, deltaSamples: [], previous: nil)
    XCTAssertFalse(none.promoted)
    XCTAssertTrue(none.activeFeatures.isEmpty)
  }

  func testDecideHysteresisKeepsAPromotedSet() {
    let base = result(auc: 0.60, brier: 0.150)
    let previous = PersonalizationSelection(features: [.heartRate], promoted: true, baseAUC: 0.58, personalizedAUC: 0.63, deltaLowerQuantile: 0.01)

    // Same set, no longer clearing the margin but not worse: stays promoted.
    let kept = PersonalizationSelection.decide(features: [.heartRate], base: base, personalized: result(auc: 0.605, brier: 0.150), deltaSamples: [], previous: previous)
    XCTAssertTrue(kept.promoted)

    // Same set, now worse than the base: dropped.
    XCTAssertFalse(PersonalizationSelection.decide(features: [.heartRate], base: base, personalized: result(auc: 0.59, brier: 0.150), deltaSamples: [], previous: previous).promoted)

    // A different set gets no hysteresis.
    XCTAssertFalse(PersonalizationSelection.decide(features: [.pressure], base: base, personalized: result(auc: 0.605, brier: 0.150), deltaSamples: [], previous: previous).promoted)
  }

  func testSelectionRoundTripsAndMetricsDecodeWithoutIt() throws {
    let selection = PersonalizationSelection(features: [.pressure, .heartRate], promoted: true, baseAUC: 0.6, personalizedAUC: 0.65, deltaLowerQuantile: 0.005)
    let data = try JSONEncoder().encode(selection)
    XCTAssertEqual(try JSONDecoder().decode(PersonalizationSelection.self, from: data), selection)

    let old = """
    {"trainedAt":700000000,"accuracy":0.7,"brier":0.2,"calibrationBuckets":[],"trainingRowCount":100,"validationRowCount":20,"positiveCount":5,"isCalibrated":true}
    """
    let metrics = try JSONDecoder().decode(ModelMetrics.self, from: Data(old.utf8))
    XCTAssertNil(metrics.personalization)
  }

}
