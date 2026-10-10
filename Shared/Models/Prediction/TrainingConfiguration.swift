//
//  TrainingConfiguration.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// The boosted-tree hyperparameters and evaluation settings used to train the
/// risk classifiers.
///
/// CreateML's defaults (depth 6, 10 iterations, step 0.3, no subsampling) are
/// tuned for large tables. On a few hundred hourly rows with ~20 positive
/// episodes they overfit: the forecast's Brier score came out worse than
/// predicting the base rate. Shallow, slow, subsampled trees are calibrated at
/// the same ranking quality, and are a prerequisite for adding the temporal
/// context columns — under the defaults, extra columns made things worse.
///
/// Pure and simulator-safe; the CreateML bridge lives in `Predictor.swift`.
struct TrainingConfiguration: Equatable {

  /// The regularized configuration used for every fit.
  static let regularized = TrainingConfiguration(
    maxDepth: 3,
    maxIterations: 150,
    stepSize: 0.05,
    minChildWeight: 4.0,
    minLossReduction: 0.5,
    rowSubsample: 0.8,
    columnSubsample: 0.5,
    randomSeed: 42)

  /// The maximum depth of each tree.
  let maxDepth: Int

  /// The number of boosting iterations (trees).
  let maxIterations: Int

  /// The learning rate.
  let stepSize: Double

  /// The minimum hessian weight required in a leaf.
  let minChildWeight: Double

  /// The minimum loss reduction required to split a node.
  let minLossReduction: Double

  /// The fraction of rows sampled per iteration.
  let rowSubsample: Double

  /// The fraction of columns sampled per iteration.
  let columnSubsample: Double

  /// The random seed, fixed so nightly retrains are reproducible.
  var randomSeed: Int

  /// The number of forward-chained folds in the rolling-origin evaluation.
  var foldCount = 5

  /// The number of cluster-bootstrap resamples for confidence intervals.
  var bootstrapResamples = 200

  /// The number of bagged members fit beside the final 24-hour model, each on
  /// an episode-cluster resample of all rows, whose spread becomes the
  /// forecast's range.
  var ensembleMembers = 6

  /// A copy with the seed offset, so each ensemble member subsamples rows
  /// and columns differently.
  ///
  /// - Parameter offset: The seed offset.
  /// - Returns: The configuration.
  func seeded(_ offset: Int) -> TrainingConfiguration {
    var copy = self
    copy.randomSeed = randomSeed + offset
    return copy
  }

}
