//
//  RollingOriginTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the simulator-safe evaluation math: classification metrics, the
/// cluster bootstrap, the rolling-origin fold plan, and metrics decoding.
final class RollingOriginTests: XCTestCase {

  // MARK: Classification metrics

  func testAUCKnownCases() throws {
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.auc(scores: [0.1, 0.2, 0.8, 0.9], outcomes: [false, false, true, true])), 1.0, accuracy: 1e-12)
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.auc(scores: [0.9, 0.8, 0.2, 0.1], outcomes: [false, false, true, true])), 0.0, accuracy: 1e-12)
    // All tied scores: chance.
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.auc(scores: [0.5, 0.5, 0.5, 0.5], outcomes: [false, true, false, true])), 0.5, accuracy: 1e-12)
    // Hand-computed: positives {0.7, 0.3}, negatives {0.5, 0.2}. Pairs won:
    // 0.7 beats both (2), 0.3 beats 0.2 (1) → 3 of 4.
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.auc(scores: [0.7, 0.5, 0.3, 0.2], outcomes: [true, false, true, false])), 0.75, accuracy: 1e-12)
  }

  func testAUCDegenerateInputs() {
    XCTAssertNil(ClassificationMetrics.auc(scores: [], outcomes: []))
    XCTAssertNil(ClassificationMetrics.auc(scores: [0.1, 0.2], outcomes: [true, true]))
    XCTAssertNil(ClassificationMetrics.auc(scores: [0.1, 0.2], outcomes: [false, false]))
    XCTAssertNil(ClassificationMetrics.auc(scores: [0.1], outcomes: [true, false]))
  }

  func testLogLossAndAccuracy() throws {
    let probabilities = [0.9, 0.1, 0.6, 0.4]
    let outcomes = [true, false, false, true]
    let expected = -(log(0.9) + log(0.9) + log(0.4) + log(0.4)) / 4.0
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.logLoss(probabilities: probabilities, outcomes: outcomes)), expected, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(ClassificationMetrics.accuracy(probabilities: probabilities, outcomes: outcomes)), 0.5, accuracy: 1e-12)
    XCTAssertNil(ClassificationMetrics.logLoss(probabilities: [], outcomes: []))
    // The clamp keeps a confident miss finite.
    XCTAssertTrue(try XCTUnwrap(ClassificationMetrics.logLoss(probabilities: [1.0], outcomes: [false])).isFinite)
  }

  func testPercentileInterpolates() {
    XCTAssertEqual(ClassificationMetrics.percentile([3.0, 1.0, 2.0], 0.5), 2.0, accuracy: 1e-12)
    XCTAssertEqual(ClassificationMetrics.percentile([1.0, 2.0], 0.25), 1.25, accuracy: 1e-12)
    XCTAssertEqual(ClassificationMetrics.percentile([7.0], 0.9), 7.0, accuracy: 1e-12)
  }

  // MARK: Cluster bootstrap

  func testClusterBootstrapIsDeterministicAndResamplesClusters() throws {
    // Four clusters of three rows each.
    let clusters: [AnyHashable] = (0 ..< 12).map({ AnyHashable($0 / 3) })

    // A statistic counting distinct clusters can never exceed the original
    // count if clusters are resampled as units.
    let distinct: ([Int]) -> Double? = { indices in Double(Set(indices.map({ $0 / 3 })).count) }
    let first = try XCTUnwrap(ClassificationMetrics.clusterBootstrap(clusters: clusters, resamples: 50, seed: 7, statistic: distinct))
    let second = try XCTUnwrap(ClassificationMetrics.clusterBootstrap(clusters: clusters, resamples: 50, seed: 7, statistic: distinct))
    XCTAssertEqual(first.samples, second.samples)
    XCTAssertEqual(first.samples.count, 50)
    XCTAssertLessThanOrEqual(first.samples.max() ?? 0.0, 4.0)
    XCTAssertGreaterThanOrEqual(first.samples.min() ?? 0.0, 1.0)

    // Each resample pools whole clusters, so its size is a multiple of three.
    _ = ClassificationMetrics.clusterBootstrap(clusters: clusters, resamples: 20, seed: 3) { indices in
      XCTAssertEqual(indices.count % 3, 0)
      XCTAssertEqual(indices.count, 12)
      return 0.0
    }
  }

  func testClusterBootstrapIntervalContainsPointEstimate() throws {
    var generator = CorrelationMath.SeededGenerator(seed: 11)
    var scores = [Double]()
    var outcomes = [Bool]()
    var clusters = [AnyHashable]()
    for cluster in 0 ..< 20 {
      for _ in 0 ..< 5 {
        let outcome = Double.random(in: 0 ... 1, using: &generator) < 0.3
        let score = (outcome ? 0.6 : 0.4) + Double.random(in: -0.3 ... 0.3, using: &generator)
        scores.append(score)
        outcomes.append(outcome)
        clusters.append(AnyHashable(cluster))
      }
    }

    let point = try XCTUnwrap(ClassificationMetrics.auc(scores: scores, outcomes: outcomes))
    let result = try XCTUnwrap(ClassificationMetrics.clusterBootstrap(clusters: clusters, resamples: 200, seed: 1) { indices in
      ClassificationMetrics.auc(scores: indices.map({ scores[$0] }), outcomes: indices.map({ outcomes[$0] }))
    })
    XCTAssertLessThanOrEqual(result.interval.lower, point)
    XCTAssertGreaterThanOrEqual(result.interval.upper, point)
    XCTAssertLessThan(result.interval.lower, result.interval.upper)
  }

  func testClusterBootstrapNeedsTwoClusters() {
    XCTAssertNil(ClassificationMetrics.clusterBootstrap(clusters: [AnyHashable(1), AnyHashable(1)], statistic: { _ in 1.0 }))
  }

  func testPairedClusterBootstrapReturnsDifferences() {
    let clusters: [AnyHashable] = (0 ..< 6).map({ AnyHashable($0 / 2) })
    let differences = ClassificationMetrics.pairedClusterBootstrap(clusters: clusters, resamples: 10, seed: 2) { _ in (0.7, 0.6) }
    XCTAssertEqual(differences.count, 10)
    for difference in differences {
      XCTAssertEqual(difference, 0.1, accuracy: 1e-12)
    }
  }

  // MARK: Rolling-origin plan

  /// Hourly dates over the given number of days, starting at local midnight.
  private func hourlyDates(days: Int, calendar: Calendar = .current) -> [Date] {
    let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
    return (0 ..< days * 24).map({ start.addingTimeInterval(TimeInterval($0) * 3600.0) })
  }

  func testRollingOriginPlanFoldsAreContiguousEmbargoedAndCoverOnce() throws {
    let calendar = Calendar.current
    let dates = hourlyDates(days: 60, calendar: calendar)
    let plan = RollingOriginPlan.make(dates: dates, foldCount: 5, calendar: calendar)

    XCTAssertEqual(plan.folds.count, 5)

    var covered = Set<Int>()
    var previousEnd: Int?
    for fold in plan.folds {
      // Test blocks start at local midnight and follow each other exactly.
      XCTAssertEqual(calendar.startOfDay(for: fold.testStart), fold.testStart)
      XCTAssertEqual(dates[fold.testIndices.lowerBound], fold.testStart)
      if let previousEnd = previousEnd {
        XCTAssertEqual(fold.testIndices.lowerBound, previousEnd)
      }
      previousEnd = fold.testIndices.upperBound

      // Training is a prefix ending at least 24h before the test block.
      XCTAssertEqual(fold.trainingIndices.lowerBound, 0)
      let newestTraining = dates[fold.trainingIndices.upperBound - 1]
      XCTAssertLessThanOrEqual(newestTraining, fold.testStart.addingTimeInterval(-RollingOriginPlan.embargo))
      XCTAssertGreaterThan(fold.trainingIndices.count, 0)

      for index in fold.testIndices {
        XCTAssertFalse(covered.contains(index))
        covered.insert(index)
      }
    }

    // The folds cover every post-warm-up row exactly once, and the warm-up
    // is at least 40% of the series.
    let firstTest = try XCTUnwrap(plan.folds.first?.testIndices.lowerBound)
    XCTAssertGreaterThanOrEqual(firstTest, Int(Double(dates.count) * RollingOriginPlan.warmUpFraction))
    XCTAssertEqual(covered.count, dates.count - firstTest)
    XCTAssertEqual(plan.folds.last?.testIndices.upperBound, dates.count)
  }

  func testRollingOriginPlanShrinksForSmallSeries() {
    let sparse = hourlyDates(days: 20).enumerated().filter({ $0.offset % 5 == 0 }).map({ $0.element })
    XCTAssertLessThan(sparse.count, RollingOriginPlan.smallSeriesCount)
    let plan = RollingOriginPlan.make(dates: sparse)
    XCTAssertEqual(plan.folds.count, RollingOriginPlan.smallSeriesFoldCount)
    XCTAssertTrue(RollingOriginPlan.make(dates: []).folds.isEmpty)
    XCTAssertTrue(RollingOriginPlan.make(dates: [Date()]).folds.isEmpty)
  }

  func testRollingOriginPlanDropsEmptyBlocks() {
    // Two days of data only: the warm-up consumes most of the series, and
    // whatever remains must still produce non-empty folds.
    let plan = RollingOriginPlan.make(dates: hourlyDates(days: 2), foldCount: 5)
    for fold in plan.folds {
      XCTAssertFalse(fold.testIndices.isEmpty)
      XCTAssertFalse(fold.trainingIndices.isEmpty)
    }
  }

  // MARK: Pooled result

  func testRollingOriginResultPoolsAndFlagsUsability() throws {
    var predictions = [RollingOriginResult.Prediction]()
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    for cluster in 0 ..< 4 {
      let onset = base.addingTimeInterval(TimeInterval(cluster) * 86400.0 * 3.0)
      for row in 0 ..< 12 {
        let outcome = row >= 8
        predictions.append(RollingOriginResult.Prediction(
          date: onset.addingTimeInterval(TimeInterval(row - 12) * 3600.0),
          rawScore: outcome ? 0.7 : 0.3,
          outcome: outcome,
          cluster: onset))
      }
    }

    let result = RollingOriginResult.pooled(folds: [], predictions: predictions, horizonHours: 24, variant: "base", resamples: 20)
    XCTAssertEqual(result.auc ?? 0.0, 1.0, accuracy: 1e-12)
    XCTAssertEqual(result.positiveCount, 16)
    XCTAssertEqual(result.negativeCount, 32)
    XCTAssertEqual(result.clusterCount, 4)
    XCTAssertTrue(result.isUsable)
    XCTAssertNotNil(result.aucInterval)
    XCTAssertNotNil(result.brier)
    XCTAssertNotNil(result.logLoss)

    let sparse = RollingOriginResult.pooled(folds: [], predictions: Array(predictions.prefix(12)), horizonHours: 24, variant: "base", resamples: 5)
    XCTAssertFalse(sparse.isUsable)

    // Round-trips through JSON (the sidecar format).
    let data = try JSONEncoder().encode(result)
    XCTAssertEqual(try JSONDecoder().decode(RollingOriginResult.self, from: data), result)
  }

  // MARK: Metrics decoding

  func testModelMetricsDecodesOldSidecarWithoutRollingFields() throws {
    let old = """
    {"trainedAt":700000000,"accuracy":0.7,"brier":0.2,"calibrationBuckets":[],"trainingRowCount":100,"validationRowCount":20,"positiveCount":5,"isCalibrated":true}
    """
    let decoded = try JSONDecoder().decode(ModelMetrics.self, from: Data(old.utf8))
    XCTAssertEqual(decoded.accuracy, 0.7)
    XCTAssertNil(decoded.source)
    XCTAssertNil(decoded.rollingAUC)
    XCTAssertNil(decoded.rollingSummary)

    var metrics = decoded
    metrics.source = .rollingOrigin
    metrics.rollingAUC = 0.64
    metrics.rollingAUCLower = 0.51
    metrics.rollingAUCUpper = 0.74
    let data = try JSONEncoder().encode(metrics)
    let roundTripped = try JSONDecoder().decode(ModelMetrics.self, from: data)
    XCTAssertEqual(roundTripped.source, .rollingOrigin)
    XCTAssertEqual(roundTripped.rollingSummary, "AUC 0.64 (0.51–0.74)")
  }

}
