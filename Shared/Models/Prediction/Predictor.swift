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

  /// The filename to use for the risk classifier.
  private static let riskClassifierFileName = "rc"

  /// Legacy model filenames from the four-model era, cleaned up on reset.
  private static let legacyFileNames = ["oc", "sc", "or", "dr"]

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

  // MARK: Private properties

  /// The classifier for predicting headache risk.
  private var riskClassifier: Model<InputUnion, RiskClassifierOutput>?

  /// The queue to do anything with models on.
  private var modelQueue = DispatchQueue(label: ApplicationKey(from: "modelQueue"))

  /// The app's current preferences.
  private var preferences = Preferences()

  /// The medians used to impute missing feature values, matching the ones
  /// used at training time.
  private var medians = FeatureMedians()

  /// The probability calibration fit at training time.
  private var calibration = PlattCalibration.identity

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
      mediansURL(),
      metricsURL(),
      importancesURL(),
      calibrationURL(),
      schemaVersionURL()
    ]
    urls.append(contentsOf: Predictor.legacyFileNames.map({ compiledModelURL(with: $0) }))

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
      self?.medians = FeatureMedians()
      self?.calibration = .identity
      self?.importances.withLock { $0 = [:] }
    }

    // Reset published state on the main queue
    DispatchQueue.main.async {
      self.modelUpdatedAt = nil
      self.modelLoadedAt = nil
      self.ready = false
      self.metrics = nil
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
          // Impute missing values with the training-time medians so the
          // model sees the same feature distribution it trained on.
          let fullInput = self.medians.imputing(input).fullInput()
          let riskPrediction = try riskClassifier.prediction(input: fullInput)
          let probability = self.calibration.apply(riskPrediction.positiveProbability)

          let prediction = RiskPrediction(
            input: input,
            probability: probability,
            topFactors: self.makeTopFactors(),
            computedAt: Date())

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

      let feature = CorrelationFeature.allCases.first(where: { $0.mlFeatureName == name })
      let insight = report?.insights.first(where: { $0.target == .occurrence && $0.feature.mlFeatureName == name })

      let direction: RiskPrediction.RiskFactor.Direction = (insight?.higherIsAssociated ?? true) ? .elevated : .reduced
      let description = insight?.directionDescription ?? feature?.title ?? name

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

        // Load the training-time medians, calibration, metrics, and
        // importances.
        if let data = try? Data(contentsOf: self.mediansURL()), let medians = try? JSONDecoder().decode(FeatureMedians.self, from: data) {
          self.medians = medians
        }
        self.calibration = (try? JSONDecoder().decode(PlattCalibration.self, from: Data(contentsOf: self.calibrationURL()))) ?? .identity
        let loadedImportances = (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: self.importancesURL()))) ?? [:]
        self.importances.withLock { $0 = loadedImportances }
        let metrics = try? JSONDecoder().decode(ModelMetrics.self, from: Data(contentsOf: self.metricsURL()))

        completion(nil)
        DispatchQueue.main.async {
          self.modelLoadedAt = Date()
          self.ready = true
          self.metrics = metrics
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

        guard !self.isTrainingCancelled else {
          finished(nil)
          return
        }

        logDebug("Training risk classifier.")
        let classifier = try MLBoostedTreeClassifier(trainingData: input.riskTable, targetColumn: RiskClassifierOutput.FeatureName.risk)

        // Permutation importances on the held-out table.
        var featureImportances = [String: Double]()
        if let validation = input.riskValidationTable {
          let evaluation = classifier.evaluation(on: validation)
          featureImportances = Predictor.normalizedImportances(
            self.permutationImportances(of: classifier, on: validation, targetColumn: RiskClassifierOutput.FeatureName.risk, baselineError: evaluation.classificationError))
        }

        // Write and compile the model so validation rows can be scored
        // per-row (CreateML exposes no per-row probabilities at training
        // time), then fit the calibration on the raw scores.
        try self.writeModel(classifier, toFileWithName: Predictor.riskClassifierFileName)

        let compiled = try Model<InputUnion, RiskClassifierOutput>(contentsOf: self.compiledModelURL(with: Predictor.riskClassifierFileName))
        var rawScores = [Double]()
        var outcomes = [Bool]()
        for validationInput in input.riskValidationInputs {
          let output = try compiled.prediction(input: validationInput.fullInput())
          rawScores.append(output.positiveProbability)
          outcomes.append(validationInput.outlook == .possibleHeadache)
        }

        let fitted = PlattCalibration.fit(scores: rawScores, outcomes: outcomes)
        let calibration = fitted ?? .identity
        let calibrated = rawScores.map(calibration.apply)

        var accuracy: Double?
        if !outcomes.isEmpty {
          let correct = zip(calibrated, outcomes).lazy.filter({ ($0.0 >= 0.5) == $0.1 }).count
          accuracy = Double(correct) / Double(outcomes.count)
        }

        let metrics = ModelMetrics(
          trainedAt: Date(),
          accuracy: accuracy,
          brier: PlattCalibration.brier(probabilities: calibrated, outcomes: outcomes),
          calibrationBuckets: PlattCalibration.buckets(probabilities: calibrated, outcomes: outcomes),
          trainingRowCount: input.riskTable.rows.count,
          validationRowCount: outcomes.count,
          positiveCount: outcomes.lazy.filter({ $0 }).count,
          isCalibrated: fitted != nil)

        if !self.isTrainingCancelled {
          // Persist the sidecars beside the model.
          try JSONEncoder().encode(input.medians).write(to: self.mediansURL(), options: .atomic)
          try JSONEncoder().encode(metrics).write(to: self.metricsURL(), options: .atomic)
          try JSONEncoder().encode(featureImportances).write(to: self.importancesURL(), options: .atomic)
          try JSONEncoder().encode(calibration).write(to: self.calibrationURL(), options: .atomic)
          try JSONEncoder().encode(Constants.modelSchemaVersion).write(to: self.schemaVersionURL(), options: .atomic)
        }

        logDebug("Getting creation date.")
        if let creationDate = try self.dateOfFile(at: self.compiledModelURL(with: Predictor.riskClassifierFileName)) {
          logDebug("Got creation date: \(creationDate.description)")
          DispatchQueue.main.async { self.modelUpdatedAt = creationDate }
        }
        else {
          logWarning("Unable to get recent model creation date.")
        }

        if self.isTrainingCancelled {
          finished(nil)
        }
        else {
          self.load { error in
            finished(error)
          }
        }
      }
      catch {
        finished(error)
      }
    }
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

  /// The URL of the persisted validation metrics.
  private func metricsURL() -> URL {
    return modelsDirectory().appendingPathComponent("metrics.json")
  }

  /// The URL of the persisted feature importances.
  private func importancesURL() -> URL {
    return modelsDirectory().appendingPathComponent("importances.json")
  }

  /// The URL of the persisted probability calibration.
  private func calibrationURL() -> URL {
    return modelsDirectory().appendingPathComponent("calibration.json")
  }

  /// The URL of the persisted feature schema version.
  private func schemaVersionURL() -> URL {
    return modelsDirectory().appendingPathComponent("schemaVersion.json")
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
