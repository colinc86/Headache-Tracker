//
//  TrainingInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

#if !targetEnvironment(simulator)
import CreateML

/// The chronologically sorted, label-derived inputs a training run works
/// from, plus the frozen medians and baselines the shipped model is paired
/// with.
///
/// The old single 80/20 split is gone: `Predictor.train` evaluates with a
/// rolling-origin plan (each fold trains on a prefix and scores the following
/// day-block, with a 24h embargo), fits the calibration on those out-of-fold
/// scores, and then fits the shipped model on every row. Tables for any slice
/// are built on demand by `table(for:medians:horizon:balanced:)` so fold
/// models impute with their own prefix's medians and never see the future.
struct TrainingInput {

  /// The maximum multiple the minority class may be duplicated to.
  static let maximumOversampleMultiple = 3

  /// The minimum rows required to train at all.
  static let minimumRowCount = 10

  /// The minimum positive rows required to train at all.
  static let minimumPositiveCount = 2

  /// The inputs, oldest first, with in-headache rows dropped and the causal
  /// baseline features attached. Not imputed.
  let inputs: [ModelInput]

  /// The medians over every row, persisted beside the shipped model so
  /// inference imputes identically.
  let medians: FeatureMedians

  /// The most-recent personal baselines, persisted beside the model so
  /// inference standardizes live autonomic readings against the same recent
  /// baseline the model trained against.
  let baselines: FeatureBaselines

  /// The forward-chained evaluation plan over `inputs`.
  let plan: RollingOriginPlan

  /// The predictor preferences frozen for this run. Providers read their
  /// toggles live, so a mid-run flip would change the column set between
  /// folds; the run reads them once here and every table uses the same set.
  let enabledFeatureNames: Set<String>

  /// Every row's correlation sample (in-headache rows included), oldest
  /// first, for the per-fold personalization candidate search.
  let correlationSamples: [CorrelationSample]

  /// Every headache episode, oldest first.
  let episodes: [HeadacheEpisode]

  /// The correlation features the user has enabled.
  let enabledFeatures: Set<CorrelationFeature>

  /// Whether the input can train a model.
  var isValid: Bool {
    return inputs.count >= Self.minimumRowCount
      && inputs.lazy.filter({ $0.isPositive(horizon: .standard) }).count >= Self.minimumPositiveCount
  }

  // MARK: Initializers

  /// Initializes new training input with an array of training data.
  ///
  /// The training data's volatile labels must already be derived (see
  /// `deriveLabels(from:)`). In-headache rows are excluded — forecasting
  /// risk during a headache is a different regime and would leak.
  ///
  /// - Parameters:
  ///   - trainingData: The training data.
  ///   - correlationSamples: The rows' correlation samples.
  ///   - episodes: The headache episodes.
  ///   - enabledFeatures: The enabled correlation features.
  init(
    trainingData: [TrainingData],
    correlationSamples: [CorrelationSample] = [],
    episodes: [HeadacheEpisode] = [],
    enabledFeatures: Set<CorrelationFeature> = Set(CorrelationFeature.allCases)
  ) throws {
    logDebug("Creating training data.")
    self.correlationSamples = correlationSamples.sorted(by: { $0.timestamp < $1.timestamp })
    self.episodes = episodes.sorted(by: { $0.start < $1.start })
    self.enabledFeatures = enabledFeatures

    // Convert to model inputs (oldest first), dropping in-headache rows.
    logDebug("Converting the training data to model inputs.")
    let rawInputs = trainingData
      .map({ $0.modelInput })
      .filter({ $0.outlook != .headache })
      .sorted(by: { $0.date < $1.date })

    // Attach causal personal-baseline features (z-scores + short-window
    // slopes) across the full sorted series (each row sees only its own
    // trailing history — no future leakage).
    inputs = BaselineFeatures.attachingBaselineFeatures(to: rawInputs)

    // Freeze the most-recent baseline and the all-rows medians for the
    // shipped model; refreshed on every retrain.
    baselines = FeatureBaselines.computed(from: inputs)
    medians = FeatureMedians.computed(from: inputs)
    plan = RollingOriginPlan.make(dates: inputs.map({ $0.date }))
    enabledFeatureNames = (inputs.first ?? .empty).fullInput().featureNames

    logDebug("Prepared \(inputs.count) inputs across \(plan.folds.count) folds.")
  }

  // MARK: Tables

  /// Builds a data table for a slice of the inputs.
  ///
  /// - Parameters:
  ///   - slice: The inputs to tabulate.
  ///   - medians: The medians to impute with (a fold's prefix medians, or the
  ///     frozen all-rows medians for the shipped model).
  ///   - horizon: The horizon whose label to build.
  ///   - balanced: Whether to balance the classes by capped duplication.
  ///   - personalized: The features whose extended temporal-context columns
  ///     the table carries.
  /// - Returns: The table.
  func table(for slice: ArraySlice<ModelInput>, medians: FeatureMedians, horizon: RiskHorizon, balanced: Bool, personalized: Set<CorrelationFeature> = []) throws -> MLDataTable {
    let imputed = TrainingInput.personalizing(slice.map(medians.imputing), with: personalized)
    let rows = balanced ? TrainingInput.balanced(imputed, horizon: horizon) : imputed
    return try MLDataTable(inputs: rows, horizon: horizon)
  }

  /// The inputs with their personalized feature set applied.
  static func personalizing(_ inputs: [ModelInput], with personalized: Set<CorrelationFeature>) -> [ModelInput] {
    return inputs.map { input in
      var copy = input
      copy.personalizedFeatures = personalized
      return copy
    }
  }

  /// The correlation report over the samples and episodes strictly before a
  /// date — the training prefix a fold may look at when choosing its
  /// personalization candidates.
  ///
  /// - Parameter cutoff: The exclusive upper bound.
  /// - Returns: The report.
  func insightsReport(before cutoff: Date) -> InsightsReport {
    let samples = correlationSamples.filter({ $0.timestamp <= cutoff })
    let priorEpisodes = episodes.filter({ $0.start <= cutoff })
    return CorrelationEngine(samples: samples, episodes: priorEpisodes, enabledFeatures: enabledFeatures).computeReport()
  }

  // MARK: Static methods

  /// Balances the binary classes by duplicating the minority class up to a
  /// cap — the honest equivalent of class weights, which CreateML boosted
  /// trees don't expose.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to balance.
  ///   - horizon: The horizon whose positive label defines the minority class.
  /// - Returns: The balanced inputs.
  static func balanced(_ inputs: [ModelInput], horizon: RiskHorizon) -> [ModelInput] {
    logDebug("Balance inputs (\(inputs.count)).")

    let positives = inputs.filter({ $0.isPositive(horizon: horizon) })
    let negatives = inputs.filter({ !$0.isPositive(horizon: horizon) })

    let (minority, majority) = positives.count <= negatives.count ? (positives, negatives) : (negatives, positives)
    guard !minority.isEmpty, !majority.isEmpty else {
      return inputs
    }

    let target = min(majority.count, minority.count * Self.maximumOversampleMultiple)
    var balanced = inputs
    var deficit = target - minority.count
    var index = 0
    while deficit > 0 {
      balanced.append(minority[index % minority.count])
      index += 1
      deficit -= 1
    }

    return balanced
  }

}
#else
struct TrainingInput {

  var isValid: Bool {
    return true
  }

  /// The inputs, oldest first.
  let inputs = [ModelInput]()

  /// The medians used to impute missing values.
  let medians = FeatureMedians()

  /// The most-recent personal baselines.
  let baselines = FeatureBaselines()

  /// The forward-chained evaluation plan.
  let plan = RollingOriginPlan(folds: [])

  /// The frozen feature names.
  let enabledFeatureNames = Set<String>()

  /// The correlation samples.
  let correlationSamples = [CorrelationSample]()

  /// The headache episodes.
  let episodes = [HeadacheEpisode]()

  /// The enabled correlation features.
  let enabledFeatures = Set<CorrelationFeature>()

  init(trainingData: [TrainingData], correlationSamples: [CorrelationSample] = [], episodes: [HeadacheEpisode] = [], enabledFeatures: Set<CorrelationFeature> = []) throws {
  }
}
#endif
