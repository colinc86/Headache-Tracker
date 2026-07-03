//
//  ModelMetrics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// Validation metrics for the trained models, computed on a chronologically
/// held-out slice that the models never trained on.
struct ModelMetrics: Codable {

  /// Metrics for a classifier.
  struct ClassifierMetrics: Codable {

    /// Accuracy on the held-out validation rows.
    let accuracy: Double

    /// The number of rows trained on (after balancing).
    let trainingRowCount: Int

    /// The number of held-out validation rows.
    let validationRowCount: Int
  }

  /// Metrics for a regressor.
  struct RegressorMetrics: Codable {

    /// Root-mean-squared error on the held-out validation rows, in seconds.
    let rootMeanSquaredError: Double

    /// The largest error on the held-out validation rows, in seconds.
    let maximumError: Double

    /// The number of rows trained on.
    let trainingRowCount: Int

    /// The number of held-out validation rows.
    let validationRowCount: Int
  }

  /// When the models were trained.
  let trainedAt: Date

  /// The outlook classifier's metrics, if a validation slice existed.
  let outlook: ClassifierMetrics?

  /// The severity classifier's metrics, if a validation slice existed.
  let severity: ClassifierMetrics?

  /// The onset regressor's metrics, if a validation slice existed.
  let onset: RegressorMetrics?

  /// The duration regressor's metrics, if a validation slice existed.
  let duration: RegressorMetrics?

}
