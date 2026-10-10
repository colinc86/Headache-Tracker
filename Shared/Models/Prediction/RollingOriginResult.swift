//
//  RollingOriginResult.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// The pooled result of a rolling-origin evaluation: every row scored by a
/// model that never saw it (or its day), plus summary metrics with an
/// episode-cluster bootstrap interval. Persisted beside the model as
/// `rolling.json`.
struct RollingOriginResult: Codable, Equatable {

  /// One fold's summary.
  struct FoldSummary: Codable, Equatable {
    let index: Int
    let trainingRowCount: Int
    let testRowCount: Int
    let positiveCount: Int
    let testStart: Date
    let testEnd: Date
    let auc: Double?
    let brier: Double?
  }

  /// One out-of-fold prediction.
  struct Prediction: Codable, Equatable {

    /// The row's date.
    let date: Date

    /// The model's raw (uncalibrated) positive probability.
    let rawScore: Double

    /// Whether an onset followed within the horizon.
    let outcome: Bool

    /// The label-generating cluster: the next onset the row's label derives
    /// from, or `.distantFuture` when none followed.
    let cluster: Date

  }

  /// The minimum positives and negatives for the pool to be usable.
  static let minimumClassCount = 10

  /// The minimum clusters for the pool to be usable.
  static let minimumClusterCount = 3

  /// When the evaluation ran.
  let computedAt: Date

  /// The horizon the labels used.
  let horizonHours: Int

  /// The model variant evaluated ("base" or "personalized").
  let variant: String

  /// The per-fold summaries.
  let folds: [FoldSummary]

  /// The pooled out-of-fold predictions.
  let predictions: [Prediction]

  /// The pooled AUC.
  let auc: Double?

  /// The cluster-bootstrap interval on the pooled AUC.
  let aucInterval: ClassificationMetrics.Interval?

  /// The pooled Brier score of the raw scores.
  let brier: Double?

  /// The pooled log loss of the raw scores.
  let logLoss: Double?

  /// The number of positive rows in the pool.
  let positiveCount: Int

  /// The number of negative rows in the pool.
  let negativeCount: Int

  /// The number of distinct clusters in the pool.
  let clusterCount: Int

  /// Whether the pool is large enough to trust.
  var isUsable: Bool {
    return positiveCount >= RollingOriginResult.minimumClassCount
      && negativeCount >= RollingOriginResult.minimumClassCount
      && clusterCount >= RollingOriginResult.minimumClusterCount
  }

  /// Pools fold predictions into a result.
  ///
  /// - Parameters:
  ///   - folds: The fold summaries.
  ///   - predictions: The out-of-fold predictions.
  ///   - horizonHours: The label horizon.
  ///   - variant: The variant name.
  ///   - resamples: The bootstrap resamples.
  /// - Returns: The result.
  static func pooled(folds: [FoldSummary], predictions: [Prediction], horizonHours: Int, variant: String, resamples: Int = 200) -> RollingOriginResult {
    let scores = predictions.map({ $0.rawScore })
    let outcomes = predictions.map({ $0.outcome })
    let clusters = predictions.map({ AnyHashable($0.cluster) })

    let interval = ClassificationMetrics.clusterBootstrap(clusters: clusters, resamples: resamples) { indices in
      ClassificationMetrics.auc(scores: indices.map({ scores[$0] }), outcomes: indices.map({ outcomes[$0] }))
    }?.interval

    return RollingOriginResult(
      computedAt: Date(),
      horizonHours: horizonHours,
      variant: variant,
      folds: folds,
      predictions: predictions,
      auc: ClassificationMetrics.auc(scores: scores, outcomes: outcomes),
      aucInterval: interval,
      brier: PlattCalibration.brier(probabilities: scores, outcomes: outcomes),
      logLoss: ClassificationMetrics.logLoss(probabilities: scores, outcomes: outcomes),
      positiveCount: outcomes.lazy.filter({ $0 }).count,
      negativeCount: outcomes.lazy.filter({ !$0 }).count,
      clusterCount: Set(predictions.map({ $0.cluster })).count)
  }

}
