//
//  ModelMetrics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// Validation metrics for the risk model.
///
/// Since the rolling-origin evaluation shipped, `accuracy`, `brier`, and
/// `calibrationBuckets` are computed over the pooled out-of-fold predictions
/// (every row scored by a model that never saw it or its day). Older sidecars
/// (`source == nil`) computed them on a single chronologically held-out slice.
/// Every field added after the first release is optional so old `metrics.json`
/// files keep decoding.
struct ModelMetrics: Codable {

  /// How the validation numbers were produced.
  enum Source: String, Codable {
    case holdout
    case rollingOrigin
  }

  /// When the model was trained.
  let trainedAt: Date

  /// Accuracy on the held-out validation rows (thresholded at 0.5).
  let accuracy: Double?

  /// The Brier score of the calibrated probabilities on the validation
  /// rows: lower is better; 0.25 is the score of always predicting 50%.
  let brier: Double?

  /// Calibration buckets: predicted vs. observed rates by probability range.
  let calibrationBuckets: [PlattCalibration.Bucket]

  /// The number of rows trained on (after balancing).
  let trainingRowCount: Int

  /// The number of held-out validation rows.
  let validationRowCount: Int

  /// The number of positive rows in the validation slice.
  let positiveCount: Int

  /// Whether a real calibration was fit; false means the validation slice
  /// was too small and probabilities pass through uncalibrated.
  let isCalibrated: Bool

  /// How the validation numbers were produced; nil for old sidecars.
  var source: Source? = nil

  /// The pooled out-of-fold AUC.
  var rollingAUC: Double? = nil

  /// The lower bound of the episode-cluster bootstrap interval on the AUC.
  var rollingAUCLower: Double? = nil

  /// The upper bound of the episode-cluster bootstrap interval on the AUC.
  var rollingAUCUpper: Double? = nil

  /// The pooled out-of-fold Brier score of the raw scores.
  var rollingBrier: Double? = nil

  /// The pooled out-of-fold log loss of the raw scores.
  var rollingLogLoss: Double? = nil

  /// The number of forward-chained folds evaluated.
  var rollingFoldCount: Int? = nil

  /// The number of positive rows in the out-of-fold pool.
  var rollingPositiveCount: Int? = nil

  /// The number of label clusters (upcoming onsets) in the pool.
  var rollingClusterCount: Int? = nil

  /// How long the whole training run took.
  var trainingDuration: TimeInterval? = nil

  /// The candidate-and-promote personalization decision for this model.
  var personalization: PersonalizationSelection? = nil

  /// The distinct calendar days the final fit saw.
  var trainingDayCount: Int? = nil

  /// The headache episodes in the training history.
  var episodeCount: Int? = nil

  /// The bagged ensemble members written beside the model (0 when the
  /// ensemble was off or skipped).
  var ensembleMemberCount: Int? = nil

  /// "Based on N days and M headaches", when both counts exist.
  var provenanceSummary: String? {
    guard let days = trainingDayCount, let episodes = episodeCount else {
      return nil
    }
    return "Based on \(days) day\(days == 1 ? "" : "s") and \(episodes) headache\(episodes == 1 ? "" : "s")"
  }

  /// The rolling-origin numbers formatted for display, when present.
  var rollingSummary: String? {
    guard let auc = rollingAUC else {
      return nil
    }
    if let lower = rollingAUCLower, let upper = rollingAUCUpper {
      return String(format: "AUC %.2f (%.2f–%.2f)", auc, lower, upper)
    }
    return String(format: "AUC %.2f", auc)
  }

}
