//
//  ModelMetrics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// Validation metrics for the risk model, computed on a chronologically
/// held-out slice the model never trained on.
struct ModelMetrics: Codable {

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

}
