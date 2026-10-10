//
//  Predictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import ApplicationKey
import CoreML
import Foundation
import os
import WidgetKit

#if !targetEnvironment(simulator)
import CreateML

extension TrainingConfiguration {

  /// The CreateML parameters for this configuration. Validation is disabled
  /// explicitly: the rolling-origin evaluation is the honest measure, and an
  /// automatic split would silently hold rows out of the shipped model.
  var modelParameters: MLBoostedTreeClassifier.ModelParameters {
    return MLBoostedTreeClassifier.ModelParameters(
      validation: .none,
      maxDepth: maxDepth,
      maxIterations: maxIterations,
      minLossReduction: minLossReduction,
      minChildWeight: minChildWeight,
      randomSeed: randomSeed,
      stepSize: stepSize,
      rowSubsample: rowSubsample,
      columnSubsample: columnSubsample)
  }

}

class Predictor: ObservableObject {

  // MARK: Types

  enum PredictorError: DescribableError {
    case unexpectedModelOutput(String)

    var description: String {
      switch self {
      case .unexpectedModelOutput(let value):
        return "The model produced an unexpected output: \(value)"
      }
    }
  }

  // MARK: Static properties

  /// The filename to use for the 24-hour risk classifier.
  private static let riskClassifierFileName = "rc"

  /// The filename to use for the shorter-horizon risk classifier.
  private static let riskShortClassifierFileName = "rc12"

  /// Legacy model filenames from the four-model era, cleaned up on reset.
  private static let legacyFileNames = ["oc", "sc", "or", "dr"]

  /// The most ensemble members ever written, bounding reset's cleanup.
  private static let maximumEnsembleMembers = 12

  /// The filename of a bagged ensemble member.
  private static func ensembleMemberFileName(_ index: Int) -> String {
    return "rcb\(index)"
  }

  /// What the ensemble sidecar records, so load never pairs stale members
  /// with a newer main model.
  private struct EnsembleManifest: Codable {
    let memberCount: Int
    let seeds: [Int]
    let trainedAt: Date
  }

  // MARK: Public properties

  /// Whether or not the predictor is training.
  @Published var training: Bool = false

  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false

  /// The predictor's latest prediction.
  @Published var prediction: RiskPrediction?

  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?

  /// The date the models were loaded.
  @Published var modelLoadedAt: Date?

  /// The latest validation metrics, computed on a chronologically held-out
  /// slice at training time.
  @Published var metrics: ModelMetrics?

  /// The latest validation metrics for the shorter-horizon classifier.
  @Published var shortMetrics: ModelMetrics?

  /// The latest rolling-origin evaluation of the 24-hour classifier.
  @Published var rolling: RollingOriginResult?

  // MARK: Private properties

  /// The classifier for predicting headache risk (24-hour horizon).
  private var riskClassifier: Model<InputUnion, RiskClassifierOutput>?

  /// The classifier for the shorter-horizon risk, when trained.
  private var riskShortClassifier: Model<InputUnion, RiskClassifierOutput>?

  /// The bagged 24-hour members whose spread becomes the forecast's range.
  /// Empty when the ensemble was off at training or failed to load.
  private var ensemble = [Model<InputUnion, RiskClassifierOutput>]()

  /// The loaded model's out-of-fold accuracy, read on the model queue so a
  /// forecast can carry it.
  private var outOfFoldAccuracy: Double?

  /// The queue to do anything with models on.
  private var modelQueue = DispatchQueue(label: ApplicationKey(from: "modelQueue"))

  /// The app's current preferences.
  private var preferences = Preferences()

  /// The predictor feature toggles, for input coverage.
  private let predictorPreferences = Preferences.Predictors()

  /// The medians used to impute missing feature values, matching the ones
  /// used at training time.
  private var medians = FeatureMedians()

  /// The most-recent personal baselines used to standardize live autonomic
  /// readings at inference, matching the ones frozen at training time.
  private var baselines = FeatureBaselines()

  /// The probability calibration fit at training time (24-hour horizon).
  private var calibration = PlattCalibration.identity

  /// The probability calibration for the shorter-horizon classifier.
  private var calibrationShort = PlattCalibration.identity

  /// The personalization decision the loaded model was trained with: which
  /// features' extended temporal-context columns it expects at inference.
  private var personalization = PersonalizationSelection.empty

  /// The latest permutation feature importances (normalized to [0, 1]).
  ///
  /// Read from arbitrary caller threads and written on the model queue, so
  /// access is lock-guarded.
  private let importances = OSAllocatedUnfairLock(initialState: [String: Double]())

  /// The predictor's training state.
  ///
  /// Accessed from the caller's thread, the model queue, and background task
  /// expiration handlers, so it's guarded by a lock. The `@Published`
  /// `training` property mirrors `isTraining` for the UI only.
  private struct TrainingState {
    var isTraining = false
    var isCancelled = false
  }

  /// The lock guarding the predictor's training state.
  private let trainingState = OSAllocatedUnfairLock(initialState: TrainingState())

  /// Whether or not training was cancelled.
  private var isTrainingCancelled: Bool {
    return trainingState.withLock { $0.isCancelled }
  }

  /// The metadata to save with a model, versioned by training time.
  private func makeMetadata() -> MLModelMetadata {
    return MLModelMetadata(
      author: "Colin Campbell",
      shortDescription: "Predicts the risk of a headache within the next 24 hours.",
      version: Date().description)
  }

  /// The prediction observer.
  private var predictionObserver: NSObjectProtocol?

  // MARK: Initializers

  init() {
    predictionObserver = Preferences.addPredictionObserver(using: predictionNotification)
    updateCurrentPredictionFromDefaults()

    do {
      logDebug("Getting creation date.")
      if let creationDate = try dateOfFile(at: compiledModelURL(with: Predictor.riskClassifierFileName)) {
        logDebug("Got creation date: \(creationDate.description)")
        DispatchQueue.main.async { self.modelUpdatedAt = creationDate }
      }
    }
    catch {
      logError("Error getting creation date: \(error)")
    }
  }

  deinit {
    if let predictionObserver = predictionObserver {
      Preferences.removePredictionObserver(predictionObserver)
    }
  }

}

// MARK: Public methods

extension Predictor {

  /// Loads the predictor's models.
  func load() async throws {
    return try await withCheckedThrowingContinuation({ [weak self] (continuation: CheckedContinuation<Void, Error>) in
      guard let self = self else {
        continuation.resume()
        return
      }

      self.load({ error in
        if let error = error {
          continuation.resume(throwing: error)
        }
        else {
          continuation.resume()
        }
      })
    })
  }

  /// Trains the predictor's classifiers.
  ///
  /// - Parameter input: The training input.
  func train(_ input: TrainingInput) async throws {
    return try await withCheckedThrowingContinuation({ [weak self] (continuation: CheckedContinuation<Void, Error>) in
      guard let self = self else {
        continuation.resume()
        return
      }

      self.train(input) { error in
        if let error = error {
          continuation.resume(throwing: error)
        }
        else {
          continuation.resume()
        }
      }
    })
  }

  /// Cancels the current training session.
  func cancelTraining() {
    logDebug("Cancel training.")
    trainingState.withLock { $0.isCancelled = true }
  }

  /// Resets the predictor and its classifiers.
  func reset() {
    // Delete the compiled model, its sidecar files, and any legacy models
    var urls = [
      compiledModelURL(with: Predictor.riskClassifierFileName),
      compiledModelURL(with: Predictor.riskShortClassifierFileName),
      mediansURL(),
      baselinesURL(),
      metricsURL(),
      metricsShortURL(),
      rollingURL(),
      rollingPersonalizedURL(),
      personalizationURL(),
      importancesURL(),
      calibrationURL(),
      calibrationShortURL(),
      schemaVersionURL(),
      ensembleManifestURL()
    ]
    urls.append(contentsOf: Predictor.legacyFileNames.map({ compiledModelURL(with: $0) }))
    urls.append(contentsOf: (0 ..< Predictor.maximumEnsembleMembers).map({ compiledModelURL(with: Predictor.ensembleMemberFileName($0)) }))

    for url in urls {
      guard FileManager.default.fileExists(atPath: url.path) else {
        continue
      }

      do {
        try FileManager.default.removeItem(at: url)
      }
      catch {
        logError("Error removing \(url.lastPathComponent): \(error)")
      }
    }

    // Unload the model on the model queue
    modelQueue.async { [weak self] in
      self?.riskClassifier = nil
      self?.riskShortClassifier = nil
      self?.ensemble = []
      self?.outOfFoldAccuracy = nil
      self?.medians = FeatureMedians()
      self?.baselines = FeatureBaselines()
      self?.calibration = .identity
      self?.calibrationShort = .identity
      self?.personalization = .empty
      self?.importances.withLock { $0 = [:] }
    }

    // Reset published state on the main queue
    DispatchQueue.main.async {
      self.modelUpdatedAt = nil
      self.modelLoadedAt = nil
      self.ready = false
      self.metrics = nil
      self.shortMetrics = nil
      self.rolling = nil
    }
  }

  /// Whether the predictor needs to load (or reload) its models.
  func needsLoading() throws -> Bool {
    guard let lastTrainingDate = try dateOfFile(at: compiledModelURL(with: Predictor.riskClassifierFileName)) else {
      return false
    }

    guard let modelLoadedAt = modelLoadedAt else {
      return true
    }

    return lastTrainingDate > modelLoadedAt
  }

  /// Makes a prediction.
  ///
  /// - Parameters:
  ///   - input: The predictor's input.
  ///   - inWidget: Whether the method is being called from a widget.
  /// - Returns: The predictor's output.
  @discardableResult
  func predict(_ input: ModelInput, inWidget: Bool) async throws -> RiskPrediction {
    if try needsLoading() {
      try await load()
    }

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else {
        continuation.resume(returning: .empty)
        return
      }

      self.modelQueue.async {
        guard let riskClassifier = self.riskClassifier else {
          continuation.resume(returning: .empty)
          return
        }

        do {
          // Standardize live autonomic readings against the frozen personal
          // baseline before imputation (z-scores use present raw values only,
          // never median-filled ones). The slope is the change in that
          // standardized value versus a reading from ~6h earlier.
          var input = input
          input.baselineZ = self.baselines.zScores(for: input.healthKitData)
          input.baselineSlope = self.baselines.slopes(current: input.healthKitData, previous: input.previousHealthKitData)
          input.personalizedFeatures = self.personalization.activeFeatures

          // Impute missing values with the training-time medians so the
          // model sees the same feature distribution it trained on, noting
          // how much of the expected input was actually measured.
          let coverage = self.medians.coverage(of: input, enabled: self.predictorPreferences.isCollectionEnabled)
          let fullInput = self.medians.imputing(input).fullInput()
          let riskPrediction = try riskClassifier.prediction(input: fullInput)
          let probability = self.calibration.apply(riskPrediction.positiveProbability)

          // The range: the spread of the bagged members, through the same
          // calibration, around the published probability.
          let interval = ForecastUncertainty.interval(point: probability, members: try self.ensembleProbabilities(for: fullInput))

          // The shorter-horizon forecast, when its classifier is trained.
          var shortProbability: Double?
          if let riskShortClassifier = self.riskShortClassifier {
            let shortPrediction = try riskShortClassifier.prediction(input: fullInput)
            shortProbability = self.calibrationShort.apply(shortPrediction.positiveProbability)
          }

          // Per-signal attribution: swap each present signal to the user's
          // baseline, re-score, and record the change in calibrated
          // probability (positive = raising risk). These are independent
          // "what if this were normal" estimates and do not sum to the total.
          // Skipped in the widget to keep timeline refreshes cheap.
          var contributions: [RiskPrediction.RiskContribution]?
          if !inWidget {
            var scored = [RiskPrediction.RiskContribution]()
            for signal in input.attributionCandidates() {
              let perturbed = self.medians.imputing(input.neutralizing(signal, medians: self.medians)).fullInput()
              let perturbedProbability = self.calibration.apply(try riskClassifier.prediction(input: perturbed).positiveProbability)
              let delta = probability - perturbedProbability
              guard abs(delta) >= 0.01 else {
                continue
              }
              let feature = signal.correlationFeature
              scored.append(RiskPrediction.RiskContribution(
                feature: feature,
                mlFeatureName: feature?.mlFeatureName ?? "\(signal)",
                delta: delta))
            }
            scored.sort { abs($0.delta) > abs($1.delta) }
            contributions = scored.isEmpty ? nil : Array(scored.prefix(8))
          }

          let prediction = RiskPrediction(
            input: input,
            probability: probability,
            topFactors: self.makeTopFactors(),
            computedAt: Date(),
            shortProbability: shortProbability,
            contributions: contributions,
            interval: interval,
            coverage: coverage,
            modelAccuracy: self.outOfFoldAccuracy)

          // Update the prediction value
          DispatchQueue.main.async {
            self.prediction = prediction
          }

          // Save this prediction for the widget
          self.preferences.shared.setCurrentRisk(prediction, inWidget: inWidget)

          continuation.resume(returning: prediction)
        }
        catch {
          continuation.resume(throwing: error)
        }
      }
    }

  }

  /// Scores an arbitrary input WITHOUT publishing or persisting it — for the
  /// live "what if…" explorer. Runs the same side-effect-free core as
  /// `predict` (baseline recompute → impute → score → calibrate) on the model
  /// queue. Returns -1 when no model is loaded.
  ///
  /// - Parameter input: The (possibly slider-modified) input to score.
  /// - Returns: The calibrated 24-hour probability.
  func probability(for input: ModelInput) async throws -> Double {
    return try await probabilities(for: [input]).first ?? -1.0
  }

  /// Scores several inputs in one pass, WITHOUT publishing or persisting —
  /// for the what-if explorer's per-signal sensitivity sweeps. One hop to the
  /// model queue for the whole batch; scoring each point through
  /// `probability(for:)` would pay a continuation per point.
  ///
  /// - Parameter inputs: The inputs to score, in order.
  /// - Returns: One calibrated 24-hour probability per input (-1 each when no
  ///   model is loaded).
  func probabilities(for inputs: [ModelInput]) async throws -> [Double] {
    return try await scores(for: inputs).map({ $0.probability24 })
  }

  /// Scores several inputs on both horizons in one pass, WITHOUT publishing
  /// or persisting — the what-if explorer's scoring call. One hop to the
  /// model queue for the whole batch.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to score, in order.
  ///   - includeInterval: Whether to score the ensemble too and carry the
  ///     24-hour range; the explorer's header asks, its curve sweeps don't.
  /// - Returns: One score per input (24h -1 when no model is loaded; 12h nil
  ///   when the shorter-horizon classifier isn't trained).
  func scores(for inputs: [ModelInput], includeInterval: Bool = false) async throws -> [ScenarioScore] {
    guard !inputs.isEmpty else {
      return []
    }

    if try needsLoading() {
      try await load()
    }

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      let empty = inputs.map({ _ in ScenarioScore(probability24: -1.0, probability12: nil) })
      guard let self = self else {
        continuation.resume(returning: empty)
        return
      }

      self.modelQueue.async {
        guard let riskClassifier = self.riskClassifier else {
          continuation.resume(returning: empty)
          return
        }

        do {
          let scored = try inputs.map { input -> ScenarioScore in
            var input = input
            input.baselineZ = self.baselines.zScores(for: input.healthKitData)
            input.baselineSlope = self.baselines.slopes(current: input.healthKitData, previous: input.previousHealthKitData)
            input.personalizedFeatures = self.personalization.activeFeatures
            let fullInput = self.medians.imputing(input).fullInput()
            let probability24 = self.calibration.apply(try riskClassifier.prediction(input: fullInput).positiveProbability)
            var probability12: Double?
            if let shortClassifier = self.riskShortClassifier {
              probability12 = self.calibrationShort.apply(try shortClassifier.prediction(input: fullInput).positiveProbability)
            }
            var score = ScenarioScore(probability24: probability24, probability12: probability12)
            if includeInterval {
              score.interval24 = ForecastUncertainty.interval(point: probability24, members: try self.ensembleProbabilities(for: fullInput))
            }
            return score
          }
          continuation.resume(returning: scored)
        }
        catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// The calibrated probabilities of every ensemble member for an imputed
  /// input, on the model queue.
  private func ensembleProbabilities(for fullInput: InputUnion) throws -> [Double] {
    return try ensemble.map { self.calibration.apply(try $0.prediction(input: fullInput).positiveProbability) }
  }

  /// The range to sweep a signal over in the what-if explorer: the user's own
  /// distribution where one is known (personal baseline mean ± 2.5σ), else the
  /// training median ± 50%, clamped to what's physically plausible.
  ///
  /// - Parameter signal: The signal to simulate.
  /// - Returns: The range, or nil when the signal has no sensible one.
  func simulationRange(for signal: RiskSignal) -> ClosedRange<Double>? {
    var range: ClosedRange<Double>?

    if case .health(let metric) = signal, let baseline = baselines.byMetric[metric], baseline.std > 0.0 {
      let spread = 2.5 * baseline.std
      range = (baseline.mean - spread) ... (baseline.mean + spread)
    }

    if range == nil {
      let median: Double?
      switch signal {
      case .health(let metric): median = medians.healthKit[metric]
      case .weather(let field): median = field.median(from: medians)
      }
      if let median = median, median != 0.0 {
        let spread = abs(median) * 0.5
        range = (median - spread) ... (median + spread)
      }
    }

    guard let bounds = signal.plausibleBounds else {
      return range
    }

    guard let range = range else {
      return bounds
    }

    let lower = min(max(range.lowerBound, bounds.lowerBound), bounds.upperBound)
    let upper = min(max(range.upperBound, bounds.lowerBound), bounds.upperBound)
    return lower < upper ? lower ... upper : bounds
  }

  /// The latest permutation feature importances, normalized to [0, 1].
  ///
  /// - Returns: Importance per feature name.
  func featureImportances() -> [String: Double] {
    return importances.withLock { importances in
      if importances.isEmpty {
        importances = (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: importancesURL()))) ?? [:]
      }
      return importances
    }
  }

}

extension Predictor {

  /// Notifies the predictor that the shared prediction was changed.
  private func predictionNotification(_ notification: Notification) {
    updateCurrentPredictionFromDefaults()
  }

  /// Updates the current prediction from the shared user defaults.
  private func updateCurrentPredictionFromDefaults() {
    DispatchQueue.main.async { [weak self] in
      self?.prediction = self?.preferences.shared.currentRisk
    }
  }

  /// The model's top contributing factors, joined to the cached correlation
  /// insights for direction and description.
  ///
  /// - Returns: The strongest factors, at most three.
  private func makeTopFactors() -> [RiskPrediction.RiskFactor] {
    let report = InsightsStore.shared.load()
    let ranked = featureImportances().sorted(by: { $0.value > $1.value }).prefix(3)

    return ranked.compactMap { name, importance -> RiskPrediction.RiskFactor? in
      guard importance > 0 else {
        return nil
      }

      let feature = CorrelationFeature.matching(mlFeatureName: name)

      // Baseline-relative columns (a deviation or trend) aren't described by
      // the base metric's level insight, so they use a qualified title.
      let isBaselineColumn = name.hasSuffix("Baseline Z") || name.hasSuffix("Baseline Slope")
      let insight = isBaselineColumn ? nil : report?.insights.first(where: { $0.target == .occurrence && $0.feature == feature })

      let description: String
      if let insight = insight {
        description = insight.directionDescription
      }
      else if let feature = feature {
        if name.hasSuffix("Baseline Slope") { description = "\(feature.title) trend" }
        else if name.hasSuffix("Baseline Z") { description = "\(feature.title) vs. baseline" }
        else { description = feature.title }
      }
      else {
        description = name
      }

      let direction: RiskPrediction.RiskFactor.Direction = (insight?.higherIsAssociated ?? true) ? .elevated : .reduced

      return RiskPrediction.RiskFactor(
        feature: feature,
        mlFeatureName: name,
        direction: direction,
        contributionDescription: description)
    }
  }

  /// Loads the predictor's models.
  ///
  /// - Parameter completion: Called after the models have been loaded.
  private func load(_ completion: @escaping (Error?) -> Void) {
    logDebug("Load models.")

    modelQueue.async { [weak self] in
      guard let self = self else {
        completion(nil)
        return
      }

      // Refuse to load models trained on an old feature schema; they'd be
      // fed feature names they don't know. This check must run here (not
      // just at app launch) because the widget process loads models from
      // the shared container independently of the app.
      let storedSchemaVersion = (try? JSONDecoder().decode(Int.self, from: Data(contentsOf: self.schemaVersionURL()))) ?? 0
      guard storedSchemaVersion == Constants.modelSchemaVersion else {
        logWarning("Compiled models use feature schema \(storedSchemaVersion), expected \(Constants.modelSchemaVersion); not loading.")
        completion(nil)
        return
      }

      do {
        logDebug("Loading risk classifier.")
        let riskClassifierModelURL = self.compiledModelURL(with: Predictor.riskClassifierFileName)
        self.riskClassifier = try Model<InputUnion, RiskClassifierOutput>(contentsOf: riskClassifierModelURL)

        // The shorter-horizon classifier is best-effort: models trained before
        // it existed simply won't have the file, and the forecast still works.
        let shortModelURL = self.compiledModelURL(with: Predictor.riskShortClassifierFileName)
        self.riskShortClassifier = try? Model<InputUnion, RiskClassifierOutput>(contentsOf: shortModelURL)
        self.calibrationShort = (try? JSONDecoder().decode(PlattCalibration.self, from: Data(contentsOf: self.calibrationShortURL()))) ?? .identity

        // The ensemble is best-effort too: no manifest or a missing member
        // means no range, never a missing forecast. All or nothing, so a
        // half-loaded ensemble can't narrow the range.
        self.ensemble = []
        if let manifest = try? JSONDecoder().decode(EnsembleManifest.self, from: Data(contentsOf: self.ensembleManifestURL())) {
          let members = (0 ..< manifest.memberCount).compactMap { index in
            try? Model<InputUnion, RiskClassifierOutput>(contentsOf: self.compiledModelURL(with: Predictor.ensembleMemberFileName(index)))
          }
          if members.count == manifest.memberCount {
            self.ensemble = members
          }
          else {
            logWarning("Loaded \(members.count) of \(manifest.memberCount) ensemble members; forecasts carry no range.")
          }
        }

        // Load the training-time medians, calibration, metrics, and
        // importances.
        if let data = try? Data(contentsOf: self.mediansURL()), let medians = try? JSONDecoder().decode(FeatureMedians.self, from: data) {
          self.medians = medians
        }
        if let data = try? Data(contentsOf: self.baselinesURL()), let baselines = try? JSONDecoder().decode(FeatureBaselines.self, from: data) {
          self.baselines = baselines
        }
        else {
          self.baselines = FeatureBaselines()
        }
        self.calibration = (try? JSONDecoder().decode(PlattCalibration.self, from: Data(contentsOf: self.calibrationURL()))) ?? .identity
        self.personalization = (try? JSONDecoder().decode(PersonalizationSelection.self, from: Data(contentsOf: self.personalizationURL()))) ?? .empty
        let loadedImportances = (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: self.importancesURL()))) ?? [:]
        self.importances.withLock { $0 = loadedImportances }
        let metrics = try? JSONDecoder().decode(ModelMetrics.self, from: Data(contentsOf: self.metricsURL()))
        self.outOfFoldAccuracy = metrics?.accuracy
        let shortMetrics = try? JSONDecoder().decode(ModelMetrics.self, from: Data(contentsOf: self.metricsShortURL()))
        let rolling = try? JSONDecoder().decode(RollingOriginResult.self, from: Data(contentsOf: self.rollingURL()))

        completion(nil)
        DispatchQueue.main.async {
          self.modelLoadedAt = Date()
          self.ready = true
          self.metrics = metrics
          self.shortMetrics = shortMetrics
          self.rolling = rolling
        }
      }
      catch {
        completion(error)
      }
    }
  }

  /// Trains the predictor's classifiers.
  ///
  /// - Parameters:
  ///   - input: The training input.
  ///   - completion: Called after training has completed.
  private func train(_ input: TrainingInput, completion: @escaping (Error?) -> Void) {
    guard input.isValid else {
      logDebug("Training data is not valid.")
      completion(nil)
      return
    }

    // Atomically claim the training session so overlapping triggers (the
    // background task and the manual train button) can't both start.
    let claimed = trainingState.withLock { state -> Bool in
      guard !state.isTraining else {
        return false
      }
      state.isTraining = true
      state.isCancelled = false
      return true
    }

    guard claimed else {
      logDebug("Training is already in progress.")
      completion(nil)
      return
    }

    DispatchQueue.main.async { [weak self] in self?.training = true }

    let finished: (Error?) -> Void = { [weak self] error in
      self?.trainingState.withLock { $0.isTraining = false }
      completion(error)
      DispatchQueue.main.async { self?.training = false }
      return
    }

    // Train the model
    modelQueue.async { [weak self] in
      do {
        guard let self = self else {
          finished(nil)
          return
        }

        let startedAt = Date()
        let configuration = TrainingConfiguration.regularized
        try self.checkCancellation()

        // 1. Rolling-origin evaluation of the 24h model: every fold trains
        //    on a prefix and scores the day-block after a 24h embargo, so the
        //    pooled scores are honest forward performance. Permutation
        //    importances come from the last fold's held-out block.
        logDebug("Evaluating risk classifier over \(input.plan.folds.count) folds.")
        let (baseRolling, featureImportances) = try self.rollingEvaluation(
          of: input,
          horizon: .standard,
          variant: "base",
          configuration: configuration,
          computeImportances: true,
          personalized: { _ in [] })

        // 1b. The personalized candidate: each fold asks the correlation
        //     engine (over that fold's prefix only) for the user's confident
        //     onset features and carries their extended context columns.
        //     Promoted only when it beats the base on the same folds.
        var rolling = baseRolling
        var rollingPersonalized: RollingOriginResult?
        var selection = PersonalizationSelection.empty
        if Preferences.Debug().personalizationEnabled, baseRolling.isUsable {
          try self.checkCancellation()
          let modelled = PersonalizationSelection.modelledFeatures().intersection(input.enabledFeatures)
          var candidatesByFold = [Int: [CorrelationFeature]]()
          for fold in input.plan.folds {
            let report = input.insightsReport(before: fold.testStart.addingTimeInterval(-RollingOriginPlan.embargo))
            candidatesByFold[fold.index] = PersonalizationSelection.candidates(from: report, modelled: modelled)
          }

          if candidatesByFold.values.contains(where: { !$0.isEmpty }) {
            logDebug("Evaluating personalized candidate.")
            let (personalizedRolling, _) = try self.rollingEvaluation(
              of: input,
              horizon: .standard,
              variant: "personalized",
              configuration: configuration,
              computeImportances: false,
              personalized: { fold in Set(candidatesByFold[fold.index] ?? []) })
            rollingPersonalized = personalizedRolling

            // Both variants scored the same rows in the same order, so the
            // paired bootstrap resamples clusters once and scores both.
            let baseScores = baseRolling.predictions.map({ $0.rawScore })
            let personalizedScores = personalizedRolling.predictions.map({ $0.rawScore })
            let outcomes = baseRolling.predictions.map({ $0.outcome })
            var deltaSamples = [Double]()
            if baseScores.count == personalizedScores.count {
              deltaSamples = ClassificationMetrics.pairedClusterBootstrap(
                clusters: baseRolling.predictions.map({ AnyHashable($0.cluster) }),
                resamples: configuration.bootstrapResamples
              ) { indices in
                guard let personalized = ClassificationMetrics.auc(scores: indices.map({ personalizedScores[$0] }), outcomes: indices.map({ outcomes[$0] })),
                      let base = ClassificationMetrics.auc(scores: indices.map({ baseScores[$0] }), outcomes: indices.map({ outcomes[$0] })) else {
                  return nil
                }
                return (personalized, base)
              }
            }

            // The shipped set comes from the engine over every row — the
            // same report Insights shows — falling back to the last fold's.
            let allRows = input.insightsReport(before: .distantFuture)
            var shipped = PersonalizationSelection.candidates(from: allRows, modelled: modelled)
            if shipped.isEmpty, let lastIndex = input.plan.folds.last?.index {
              shipped = candidatesByFold[lastIndex] ?? []
            }
            selection = PersonalizationSelection.decide(
              features: shipped,
              base: baseRolling,
              personalized: personalizedRolling,
              deltaSamples: deltaSamples,
              previous: self.personalization)
            if selection.promoted {
              rolling = personalizedRolling
            }
            logInfo("Personalization: \(selection.statusDescription)")
          }
        }
        let activeFeatures = selection.activeFeatures

        // 2. Calibration from the out-of-fold raw scores of the winning pool.
        //    Too few positives or negatives and the model ships uncalibrated
        //    (and unevaluated), exactly as the old undersized validation
        //    slice did.
        let rawScores = rolling.predictions.map({ $0.rawScore })
        let outcomes = rolling.predictions.map({ $0.outcome })
        let fitted = rolling.isUsable ? PlattCalibration.fit(scores: rawScores, outcomes: outcomes) : nil
        let calibration = fitted ?? .identity
        let calibrated = rawScores.map(calibration.apply)

        // 3. The shorter horizon follows the same folds with its own labels
        //    and calibration; no bootstrap, no importances.
        try self.checkCancellation()
        logDebug("Evaluating shorter-horizon risk classifier.")
        let (rollingShort, _) = try self.rollingEvaluation(
          of: input,
          horizon: .short,
          variant: selection.promoted ? "personalized" : "base",
          configuration: configuration,
          computeImportances: false,
          personalized: { _ in activeFeatures })
        let shortRawScores = rollingShort.predictions.map({ $0.rawScore })
        let shortOutcomes = rollingShort.predictions.map({ $0.outcome })
        let shortFitted = rollingShort.isUsable ? PlattCalibration.fit(scores: shortRawScores, outcomes: shortOutcomes) : nil
        let shortCalibration = shortFitted ?? .identity
        let shortCalibrated = shortRawScores.map(shortCalibration.apply)

        // 3b. The bagged ensemble: members fit on episode-cluster resamples
        //     of all rows, each with its own seed, whose spread becomes the
        //     forecast's range. Fit in memory here, with a cancellation gate
        //     per member, and written only past the final gate below.
        let all = input.inputs[...]
        var members = [MLBoostedTreeClassifier]()
        var memberSeeds = [Int]()
        if Preferences.Debug().ensembleEnabled, rolling.isUsable {
          let clusters = all.map({ AnyHashable($0.labelCluster()) })
          let resamples = ClassificationMetrics.clusterResamples(clusters: clusters, resamples: configuration.ensembleMembers, seed: UInt64(configuration.randomSeed))
          for (index, rows) in resamples.enumerated() {
            try self.checkCancellation()
            let member = configuration.seeded(index + 1)
            let table = try input.table(for: ArraySlice(rows.map({ all[$0] })), medians: input.medians, horizon: .standard, balanced: true, personalized: activeFeatures)
            members.append(try self.fitClassifier(on: table, configuration: member))
            memberSeeds.append(member.randomSeed)
            logDebug("Ensemble member \(index + 1)/\(resamples.count) fit on \(rows.count) rows.")
          }
        }

        // 4. The last cancellation gate: past it, both models and every
        //    sidecar are written together so nothing can mismatch. Reaching
        //    it after the evaluation means an expired background task leaves
        //    the previous model and sidecars intact.
        try self.checkCancellation()

        // 5. Final fits on every row with the frozen all-rows medians.
        logDebug("Training risk classifier on all rows.")
        let riskTable = try input.table(for: all, medians: input.medians, horizon: .standard, balanced: true, personalized: activeFeatures)
        let classifier = try self.fitClassifier(on: riskTable, configuration: configuration)
        logDebug("Risk classifier trained (automatic validation split active: \(classifier.validationMetrics.isValid)).")
        try self.writeModel(classifier, toFileWithName: Predictor.riskClassifierFileName)

        logDebug("Training shorter-horizon risk classifier on all rows.")
        let riskShortTable = try input.table(for: all, medians: input.medians, horizon: .short, balanced: true, personalized: activeFeatures)
        let shortClassifier = try self.fitClassifier(on: riskShortTable, configuration: configuration)
        try self.writeModel(shortClassifier, toFileWithName: Predictor.riskShortClassifierFileName)

        // The ensemble members, then stale members beyond the new count so a
        // shorter ensemble never picks up an older model's leftovers.
        for (index, member) in members.enumerated() {
          try self.writeModel(member, toFileWithName: Predictor.ensembleMemberFileName(index))
        }
        for index in min(members.count, Predictor.maximumEnsembleMembers) ..< Predictor.maximumEnsembleMembers {
          try? FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.ensembleMemberFileName(index)))
        }

        // 6. Metrics and sidecars.
        var metrics = ModelMetrics(
          trainedAt: Date(),
          accuracy: ClassificationMetrics.accuracy(probabilities: calibrated, outcomes: outcomes),
          brier: PlattCalibration.brier(probabilities: calibrated, outcomes: outcomes),
          calibrationBuckets: PlattCalibration.buckets(probabilities: calibrated, outcomes: outcomes),
          trainingRowCount: riskTable.rows.count,
          validationRowCount: outcomes.count,
          positiveCount: rolling.positiveCount,
          isCalibrated: fitted != nil)
        metrics.source = .rollingOrigin
        metrics.rollingAUC = rolling.auc
        metrics.rollingAUCLower = rolling.aucInterval?.lower
        metrics.rollingAUCUpper = rolling.aucInterval?.upper
        metrics.rollingBrier = rolling.brier
        metrics.rollingLogLoss = rolling.logLoss
        metrics.rollingFoldCount = rolling.folds.count
        metrics.rollingPositiveCount = rolling.positiveCount
        metrics.rollingClusterCount = rolling.clusterCount
        metrics.trainingDuration = Date().timeIntervalSince(startedAt)
        metrics.personalization = selection
        metrics.trainingDayCount = Set(all.map({ Calendar.current.startOfDay(for: $0.date) })).count
        metrics.episodeCount = input.episodes.count
        metrics.ensembleMemberCount = members.count

        var shortMetrics = ModelMetrics(
          trainedAt: Date(),
          accuracy: ClassificationMetrics.accuracy(probabilities: shortCalibrated, outcomes: shortOutcomes),
          brier: PlattCalibration.brier(probabilities: shortCalibrated, outcomes: shortOutcomes),
          calibrationBuckets: PlattCalibration.buckets(probabilities: shortCalibrated, outcomes: shortOutcomes),
          trainingRowCount: riskShortTable.rows.count,
          validationRowCount: shortOutcomes.count,
          positiveCount: rollingShort.positiveCount,
          isCalibrated: shortFitted != nil)
        shortMetrics.source = .rollingOrigin
        shortMetrics.rollingAUC = rollingShort.auc
        shortMetrics.rollingBrier = rollingShort.brier
        shortMetrics.rollingLogLoss = rollingShort.logLoss
        shortMetrics.rollingFoldCount = rollingShort.folds.count
        shortMetrics.rollingPositiveCount = rollingShort.positiveCount
        shortMetrics.rollingClusterCount = rollingShort.clusterCount

        // Persist the sidecars beside the models unconditionally — the model
        // files are already in place, and skipping these would mismatch them.
        let encoder = JSONEncoder()
        try encoder.encode(input.medians).write(to: self.mediansURL(), options: .atomic)
        try encoder.encode(input.baselines).write(to: self.baselinesURL(), options: .atomic)
        try encoder.encode(metrics).write(to: self.metricsURL(), options: .atomic)
        try encoder.encode(featureImportances).write(to: self.importancesURL(), options: .atomic)
        try encoder.encode(calibration).write(to: self.calibrationURL(), options: .atomic)
        try encoder.encode(rolling).write(to: self.rollingURL(), options: .atomic)
        try encoder.encode(selection).write(to: self.personalizationURL(), options: .atomic)
        if let rollingPersonalized = rollingPersonalized {
          try encoder.encode(rollingPersonalized).write(to: self.rollingPersonalizedURL(), options: .atomic)
        }
        else {
          try? FileManager.default.removeItem(at: self.rollingPersonalizedURL())
        }
        try encoder.encode(shortCalibration).write(to: self.calibrationShortURL(), options: .atomic)
        try encoder.encode(shortMetrics).write(to: self.metricsShortURL(), options: .atomic)
        try encoder.encode(Constants.modelSchemaVersion).write(to: self.schemaVersionURL(), options: .atomic)
        if members.isEmpty {
          try? FileManager.default.removeItem(at: self.ensembleManifestURL())
        }
        else {
          try encoder.encode(EnsembleManifest(memberCount: members.count, seeds: memberSeeds, trainedAt: Date())).write(to: self.ensembleManifestURL(), options: .atomic)
        }

        logInfo("Trained in \(Int(metrics.trainingDuration ?? 0))s: \(metrics.rollingSummary ?? "unevaluated"), Brier \(metrics.brier.map({ String(format: "%.3f", $0) }) ?? "–"), \(members.count) ensemble members, \(metrics.trainingDayCount ?? 0) days / \(metrics.episodeCount ?? 0) episodes.")

        logDebug("Getting creation date.")
        if let creationDate = try self.dateOfFile(at: self.compiledModelURL(with: Predictor.riskClassifierFileName)) {
          logDebug("Got creation date: \(creationDate.description)")
          DispatchQueue.main.async { self.modelUpdatedAt = creationDate }
        }
        else {
          logWarning("Unable to get recent model creation date.")
        }

        self.load { error in
          finished(error)
        }
      }
      catch is TrainingCancelled {
        logDebug("Training cancelled.")
        finished(nil)
      }
      catch {
        finished(error)
      }
    }
  }

  /// Thrown between training steps when a cancellation was requested.
  private struct TrainingCancelled: Error {}

  /// Throws when training was cancelled.
  private func checkCancellation() throws {
    if isTrainingCancelled {
      throw TrainingCancelled()
    }
  }

  /// Fits a boosted-tree classifier on a table.
  private func fitClassifier(on table: MLDataTable, configuration: TrainingConfiguration) throws -> MLBoostedTreeClassifier {
    return try MLBoostedTreeClassifier(trainingData: table, targetColumn: RiskClassifierOutput.FeatureName.risk, parameters: configuration.modelParameters)
  }

  /// Scores inputs through a freshly trained classifier without writing it
  /// beside the shipped model.
  ///
  /// The trainer exposes only labels per row, but its `model` is a plain
  /// `MLModel`, so it can be wrapped and scored in memory. Should that fail on
  /// device, the classifier is written and compiled into a temporary
  /// directory that is removed afterwards.
  ///
  /// - Parameters:
  ///   - classifier: The trained classifier.
  ///   - inputs: The (already imputed) inputs to score.
  /// - Returns: The raw positive probability per input.
  private func rawScores(of classifier: MLBoostedTreeClassifier, for inputs: [ModelInput]) throws -> [Double] {
    let scorer: (Model<InputUnion, RiskClassifierOutput>) throws -> [Double] = { model in
      try inputs.map({ try model.prediction(input: $0.fullInput()).positiveProbability })
    }

    do {
      return try scorer(Model<InputUnion, RiskClassifierOutput>(model: classifier.model))
    }
    catch {
      logWarning("In-memory scoring failed (\(error)); compiling a temporary model.")
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rolling-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }

      let modelURL = directory.appendingPathComponent("fold.mlmodel")
      try classifier.write(to: modelURL, metadata: makeMetadata())
      let compiledURL = try MLModel.compileModel(at: modelURL)
      return try scorer(Model<InputUnion, RiskClassifierOutput>(contentsOf: compiledURL))
    }
  }

  /// Runs the rolling-origin evaluation for one horizon.
  ///
  /// - Parameters:
  ///   - input: The training input.
  ///   - horizon: The label horizon.
  ///   - variant: The variant name recorded in the result.
  ///   - configuration: The training configuration.
  ///   - computeImportances: Whether to compute permutation importances on
  ///     the last fold's held-out block.
  ///   - personalized: The personalized feature set to carry in each fold.
  /// - Returns: The pooled result and the normalized importances (empty when
  ///   not computed).
  private func rollingEvaluation(
    of input: TrainingInput,
    horizon: RiskHorizon,
    variant: String,
    configuration: TrainingConfiguration,
    computeImportances: Bool,
    personalized: (RollingOriginPlan.Fold) -> Set<CorrelationFeature>
  ) throws -> (RollingOriginResult, [String: Double]) {
    var summaries = [RollingOriginResult.FoldSummary]()
    var predictions = [RollingOriginResult.Prediction]()
    var importances = [String: Double]()

    for fold in input.plan.folds {
      try checkCancellation()

      let prefix = input.inputs[fold.trainingIndices]
      let block = input.inputs[fold.testIndices]
      guard prefix.contains(where: { $0.isPositive(horizon: horizon) }), prefix.contains(where: { !$0.isPositive(horizon: horizon) }) else {
        logDebug("Fold \(fold.index) skipped: the prefix has one class.")
        continue
      }

      let features = personalized(fold)
      let foldMedians = FeatureMedians.computed(from: Array(prefix))
      let table = try input.table(for: prefix, medians: foldMedians, horizon: horizon, balanced: true, personalized: features)
      let classifier = try fitClassifier(on: table, configuration: configuration)

      let imputedBlock = TrainingInput.personalizing(block.map(foldMedians.imputing), with: features)
      let scores = try rawScores(of: classifier, for: imputedBlock)
      let outcomes = imputedBlock.map({ $0.isPositive(horizon: horizon) })

      for (row, score) in zip(imputedBlock, scores) {
        predictions.append(RollingOriginResult.Prediction(date: row.date, rawScore: score, outcome: row.isPositive(horizon: horizon), cluster: row.labelCluster()))
      }

      summaries.append(RollingOriginResult.FoldSummary(
        index: fold.index,
        trainingRowCount: prefix.count,
        testRowCount: block.count,
        positiveCount: outcomes.lazy.filter({ $0 }).count,
        testStart: fold.testStart,
        testEnd: fold.testEnd,
        auc: ClassificationMetrics.auc(scores: scores, outcomes: outcomes),
        brier: PlattCalibration.brier(probabilities: scores, outcomes: outcomes)))

      if computeImportances && fold.index == input.plan.folds.count - 1 {
        let validation = try input.table(for: block, medians: foldMedians, horizon: horizon, balanced: false, personalized: features)
        let baseline = classifier.evaluation(on: validation)
        importances = Predictor.normalizedImportances(
          permutationImportances(of: classifier, on: validation, targetColumn: RiskClassifierOutput.FeatureName.risk, baselineError: baseline.classificationError))
      }
    }

    let result = RollingOriginResult.pooled(
      folds: summaries,
      predictions: predictions,
      horizonHours: Int(horizon.window / 3600.0),
      variant: variant,
      resamples: computeImportances ? configuration.bootstrapResamples : 0)
    return (result, importances)
  }

  /// Permutation importance of each feature: the accuracy drop when that
  /// feature's validation column is shuffled. Boosted trees expose no
  /// importances directly, so this measures what the model actually relies
  /// on.
  ///
  /// - Parameters:
  ///   - classifier: The trained classifier.
  ///   - validation: The held-out validation table.
  ///   - targetColumn: The target column's name.
  ///   - baselineError: The classifier's error on the unshuffled table.
  /// - Returns: The non-negative accuracy drop per feature column.
  private func permutationImportances(of classifier: MLBoostedTreeClassifier, on validation: MLDataTable, targetColumn: String, baselineError: Double) -> [String: Double] {
    var importances = [String: Double]()
    var generator = SystemRandomNumberGenerator()

    for column in validation.columnNames where column != targetColumn {
      guard let values = validation[column].doubles.map(Array.init) else {
        continue
      }

      var shuffled = values
      shuffled.shuffle(using: &generator)

      var permuted = validation
      permuted.removeColumn(named: column)
      permuted.addColumn(MLDataColumn(shuffled), named: column)

      let error = classifier.evaluation(on: permuted).classificationError
      importances[column] = max(0.0, error - baselineError)
    }

    return importances
  }

  /// Normalizes importances to [0, 1] by the maximum value.
  private static func normalizedImportances(_ importances: [String: Double]) -> [String: Double] {
    guard let maximum = importances.values.max(), maximum > 0.0 else {
      return importances
    }
    return importances.mapValues({ $0 / maximum })
  }

  /// Writes the model to the file with the given model name.
  ///
  /// - Parameters:
  ///   - model: The model to write to file.
  ///   - fileName: The filename to use.
  private func writeModel<T: CoreMLModel>(_ model: T, toFileWithName fileName: String) throws {
    // Write the trained model to file
    let modelURL = modelURL(with: fileName)
    try model.write(to: modelURL, metadata: makeMetadata())

    // Compile the model
    let newCompiledModelURL = try MLModel.compileModel(at: modelURL)

    // Replace the old compiled model with the new one
    let compiledModelURL = compiledModelURL(with: fileName)
    _ = try FileManager.default.replaceItemAt(compiledModelURL, withItemAt: newCompiledModelURL)

    // Remove the pre-compiled model
    try FileManager.default.removeItem(at: modelURL)
  }

  /// The date of the file with the given url.
  ///
  /// - Parameter url: The url of the file.
  /// - Returns: The file's creation date, or `nil` if the file doesn't exist.
  private func dateOfFile(at url: URL) throws -> Date? {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return attributes[.modificationDate] as? Date ?? attributes[.creationDate] as? Date
  }

  /// The URL of a model with the given name.
  ///
  /// - Parameter name: The name of the model.
  /// - Returns: The URL of the model.
  private func modelURL(with name: String) -> URL {
    return modelsDirectory().appendingPathComponent("\(name).mlmodel")
  }

  /// The URL of a compiled model with the given name.
  ///
  /// - Parameter name: The name of the compiled model.
  /// - Returns: The URL of the compiled model.
  private func compiledModelURL(with name: String) -> URL {
    return modelsDirectory().appendingPathComponent("\(name).mlmodelc")
  }

  /// The URL of the persisted feature medians.
  private func mediansURL() -> URL {
    return modelsDirectory().appendingPathComponent("medians.json")
  }

  /// The URL of the persisted personal baselines.
  private func baselinesURL() -> URL {
    return modelsDirectory().appendingPathComponent("baselines.json")
  }

  /// The URL of the persisted validation metrics.
  private func metricsURL() -> URL {
    return modelsDirectory().appendingPathComponent("metrics.json")
  }

  /// The URL of the persisted shorter-horizon validation metrics.
  private func metricsShortURL() -> URL {
    return modelsDirectory().appendingPathComponent("metricsShort.json")
  }

  /// The URL of the persisted rolling-origin evaluation.
  private func rollingURL() -> URL {
    return modelsDirectory().appendingPathComponent("rolling.json")
  }

  /// The URL of the persisted rolling-origin evaluation of the personalized
  /// candidate, when one was evaluated.
  private func rollingPersonalizedURL() -> URL {
    return modelsDirectory().appendingPathComponent("rollingPersonalized.json")
  }

  /// The URL of the persisted personalization decision.
  private func personalizationURL() -> URL {
    return modelsDirectory().appendingPathComponent("personalization.json")
  }

  /// The URL of the persisted feature importances.
  private func importancesURL() -> URL {
    return modelsDirectory().appendingPathComponent("importances.json")
  }

  /// The URL of the persisted probability calibration.
  private func calibrationURL() -> URL {
    return modelsDirectory().appendingPathComponent("calibration.json")
  }

  /// The URL of the persisted shorter-horizon probability calibration.
  private func calibrationShortURL() -> URL {
    return modelsDirectory().appendingPathComponent("calibrationShort.json")
  }

  /// The URL of the persisted feature schema version.
  private func schemaVersionURL() -> URL {
    return modelsDirectory().appendingPathComponent("schemaVersion.json")
  }

  /// The URL of the persisted ensemble manifest.
  private func ensembleManifestURL() -> URL {
    return modelsDirectory().appendingPathComponent("ensemble.json")
  }

  /// The predictor's models directory.
  ///
  /// - Returns: A URL.
  private func modelsDirectory() -> URL {
    let fileContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return fileContainerURL.appendingPathComponent("models")
  }

}
#endif
