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

  enum ModelType {
    case durationRegressor
    case onsetRegressor
    case outlookClassifier
    case severityClassifier
  }

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
  
  /// The filename to use for the outlook classifier.
  private static let outlookClassifierFileName = "oc"
  
  /// The filename to use for the severity classifier.
  private static let severityClassifierFileName = "sc"
  
  /// The filename to use for the onset regressor.
  private static let onsetRegressorFileName = "or"
  
  /// The filename to use for the duration regressor.
  private static let durationRegressorFileName = "dr"
  
  // MARK: Public properties
  
  /// Whether or not the predictor is training.
  @Published var training: Bool = false
  
  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false
  
  /// The predictor's latest prediction.
  @Published var prediction: PredictionOutput?
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?
  
  /// The date the models were loaded.
  @Published var modelLoadedAt: Date?

  /// The latest validation metrics, computed on a chronologically held-out
  /// slice at training time.
  @Published var metrics: ModelMetrics?

  // MARK: Private properties

  /// The medians used to impute missing feature values, matching the ones
  /// used at training time.
  private var medians = FeatureMedians()

  /// The latest permutation feature importances (normalized to [0, 1]).
  private var importances = [String: Double]()
  
  /// The classifier for predicting headache outlook.
  private var outlookClassifier: Model<InputUnion, OutlookClassifierOutput>?
  
  /// The classifier for predicting headache severities.
  private var severityClassifier: Model<InputUnion, SeverityClassifierOutput>?
  
  /// The regressor for predicting headache onset.
  private var onsetRegressor: Model<InputUnion, OnsetRegressorOutput>?
  
  /// The regressor for predicting headache duration.
  private var durationRegressor: Model<InputUnion, DurationRegressorOutput>?
  
  /// The queue to do anything with models on.
  private var modelQueue = DispatchQueue(label: ApplicationKey(from: "modelQueue"))
  
  /// The app's current preferences.
  private var preferences = Preferences()

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
      shortDescription: "Predicts the onset, severity and progression of headaches.",
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
      if let creationDate = try dateOfFile(at: compiledModelURL(with: Predictor.outlookClassifierFileName)) {
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
    // Delete the compiled models and their sidecar files
    let urls = [
      compiledModelURL(with: Predictor.outlookClassifierFileName),
      compiledModelURL(with: Predictor.severityClassifierFileName),
      compiledModelURL(with: Predictor.onsetRegressorFileName),
      compiledModelURL(with: Predictor.durationRegressorFileName),
      mediansURL(),
      metricsURL(),
      importancesURL()
    ]

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

    // Unload the models on the model queue
    modelQueue.async { [weak self] in
      self?.outlookClassifier = nil
      self?.severityClassifier = nil
      self?.onsetRegressor = nil
      self?.durationRegressor = nil
      self?.medians = FeatureMedians()
      self?.importances = [:]
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
    guard let lastTrainingDate = try dateOfFile(at: compiledModelURL(with: Predictor.outlookClassifierFileName)) else {
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
  func predict(_ input: ModelInput, inWidget: Bool) async throws -> PredictionOutput {
    if try needsLoading() {
      try await load()
    }

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else {
        continuation.resume(returning: .empty)
        return
      }

      self.modelQueue.async {
        guard let outlookClassifier = self.outlookClassifier,
              let severityClassifier = self.severityClassifier,
              let onsetRegressor = self.onsetRegressor,
              let durationRegressor = self.durationRegressor else {
                continuation.resume(returning: .empty)
                return
              }

        do {
          // Impute missing values with the training-time medians so the
          // models see the same feature distribution they trained on.
          let fullInput = self.medians.imputing(input).fullInput()
          let outlookPrediction = try outlookClassifier.prediction(input: fullInput)
          let severityPrediction = try severityClassifier.prediction(input: fullInput)
          let onsetPrediction = try onsetRegressor.prediction(input: fullInput)
          let durationPrediction = try durationRegressor.prediction(input: fullInput)

          guard let severity = Headache.Severity(title: severityPrediction.Severity) else {
            throw PredictorError.unexpectedModelOutput(severityPrediction.Severity)
          }

          let prediction = PredictionOutput(
            input: input,

            outlookClassifierOutput: PredictionOutput.PredictionStatistic(
              prediction: Outlook(rawValue: outlookPrediction.Outlook) ?? .noHeadache,
              probability: outlookPrediction.OutlookProbability[outlookPrediction.Outlook]),

            severityClassifierOutput: PredictionOutput.PredictionStatistic(
              prediction: severity,
              probability: severityPrediction.SeverityProbability[severityPrediction.Severity]),

            onsetRegressorOutput: PredictionOutput.PredictionStatistic<Date>(
              prediction: Date().addingTimeInterval(onsetPrediction.Onset),
              probability: nil),

            // The duration model's target is time remaining until the
            // current headache ends, not total duration.
            durationRegressorOutput: PredictionOutput.PredictionStatistic<TimeInterval>(
              prediction: durationPrediction.Duration,
              probability: nil)
          )

          // Update the prediction value
          DispatchQueue.main.async {
            self.prediction = prediction
          }

          // Save this prediction for the widget
          self.preferences.shared.setCurrentPrediction(prediction, inWidget: inWidget)

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
    if importances.isEmpty {
      importances = (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: importancesURL()))) ?? [:]
    }
    return importances
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
      self?.prediction = self?.preferences.shared.currentPrediction
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
      
      do {
        logDebug("Loading outlook classifier.")
        let outlookClassifierModelURL = self.compiledModelURL(with: Predictor.outlookClassifierFileName)
        self.outlookClassifier = try Model<InputUnion, OutlookClassifierOutput>(contentsOf: outlookClassifierModelURL)
        
        logDebug("Loading severity classifier.")
        let severityClassifierModelURL = self.compiledModelURL(with: Predictor.severityClassifierFileName)
        self.severityClassifier = try Model<InputUnion, SeverityClassifierOutput>(contentsOf: severityClassifierModelURL)
        
        logDebug("Loading onset regressor.")
        let onsetRegressorModelURL = self.compiledModelURL(with: Predictor.onsetRegressorFileName)
        self.onsetRegressor = try Model<InputUnion, OnsetRegressorOutput>(contentsOf: onsetRegressorModelURL)
        
        logDebug("Loading duration regressor.")
        let durationRegressorModelURL = self.compiledModelURL(with: Predictor.durationRegressorFileName)
        self.durationRegressor = try Model<InputUnion, DurationRegressorOutput>(contentsOf: durationRegressorModelURL)

        // Load the training-time medians, metrics, and importances.
        if let data = try? Data(contentsOf: self.mediansURL()), let medians = try? JSONDecoder().decode(FeatureMedians.self, from: data) {
          self.medians = medians
        }
        self.importances = (try? JSONDecoder().decode([String: Double].self, from: Data(contentsOf: self.importancesURL()))) ?? [:]
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
    
    // Train the models
    modelQueue.async { [weak self] in
      do {
        guard let self = self else {
          finished(nil)
          return
        }

        var outlookMetrics: ModelMetrics.ClassifierMetrics?
        var severityMetrics: ModelMetrics.ClassifierMetrics?
        var onsetMetrics: ModelMetrics.RegressorMetrics?
        var durationMetrics: ModelMetrics.RegressorMetrics?
        var featureImportances = [String: Double]()

        // Train the outlook classifier
        if !self.isTrainingCancelled {
          logDebug("Training outlook classifier.")
          let classifier = try MLBoostedTreeClassifier(trainingData: input.outlookTable, targetColumn: OutlookClassifierOutput.FeatureName.outlook)

          if let validation = input.outlookValidationTable {
            let evaluation = classifier.evaluation(on: validation)
            outlookMetrics = ModelMetrics.ClassifierMetrics(
              accuracy: 1.0 - evaluation.classificationError,
              trainingRowCount: input.outlookTable.rows.count,
              validationRowCount: validation.rows.count)
            self.mergeImportances(
              into: &featureImportances,
              from: self.permutationImportances(of: classifier, on: validation, targetColumn: OutlookClassifierOutput.FeatureName.outlook, baselineError: evaluation.classificationError))
          }

          try self.writeModel(classifier, toFileWithName: Predictor.outlookClassifierFileName)
        }

        // Train the severity classifier
        if !self.isTrainingCancelled {
          logDebug("Training severity classifier.")
          let classifier = try MLBoostedTreeClassifier(trainingData: input.severityTable, targetColumn: SeverityClassifierOutput.FeatureName.severity)

          if let validation = input.severityValidationTable {
            let evaluation = classifier.evaluation(on: validation)
            severityMetrics = ModelMetrics.ClassifierMetrics(
              accuracy: 1.0 - evaluation.classificationError,
              trainingRowCount: input.severityTable.rows.count,
              validationRowCount: validation.rows.count)
            self.mergeImportances(
              into: &featureImportances,
              from: self.permutationImportances(of: classifier, on: validation, targetColumn: SeverityClassifierOutput.FeatureName.severity, baselineError: evaluation.classificationError))
          }

          try self.writeModel(classifier, toFileWithName: Predictor.severityClassifierFileName)
        }

        // Train the onset regressor
        if !self.isTrainingCancelled {
          logDebug("Training onset regressor.")
          let regressor = try MLBoostedTreeRegressor(trainingData: input.onsetTable, targetColumn: OnsetRegressorOutput.FeatureName.onset)

          if let validation = input.onsetValidationTable {
            let evaluation = regressor.evaluation(on: validation)
            onsetMetrics = ModelMetrics.RegressorMetrics(
              rootMeanSquaredError: evaluation.rootMeanSquaredError,
              maximumError: evaluation.maximumError,
              trainingRowCount: input.onsetTable.rows.count,
              validationRowCount: validation.rows.count)
          }

          try self.writeModel(regressor, toFileWithName: Predictor.onsetRegressorFileName)
        }

        // Train the duration regressor
        if !self.isTrainingCancelled {
          logDebug("Training duration regressor.")
          let regressor = try MLBoostedTreeRegressor(trainingData: input.durationTable, targetColumn: DurationRegressorOutput.FeatureName.duration)

          if let validation = input.durationValidationTable {
            let evaluation = regressor.evaluation(on: validation)
            durationMetrics = ModelMetrics.RegressorMetrics(
              rootMeanSquaredError: evaluation.rootMeanSquaredError,
              maximumError: evaluation.maximumError,
              trainingRowCount: input.durationTable.rows.count,
              validationRowCount: validation.rows.count)
          }

          try self.writeModel(regressor, toFileWithName: Predictor.durationRegressorFileName)
        }

        if !self.isTrainingCancelled {
          // Persist the medians, metrics, and importances beside the models.
          let metrics = ModelMetrics(
            trainedAt: Date(),
            outlook: outlookMetrics,
            severity: severityMetrics,
            onset: onsetMetrics,
            duration: durationMetrics)

          try JSONEncoder().encode(input.medians).write(to: self.mediansURL(), options: .atomic)
          try JSONEncoder().encode(metrics).write(to: self.metricsURL(), options: .atomic)
          try JSONEncoder().encode(featureImportances).write(to: self.importancesURL(), options: .atomic)
        }

        logDebug("Getting creation date.")
        if let creationDate = try self.dateOfFile(at: self.compiledModelURL(with: Predictor.outlookClassifierFileName)) {
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

  /// Merges per-model importances into the combined dictionary, keeping the
  /// larger value per feature and normalizing to [0, 1] by the maximum.
  private func mergeImportances(into combined: inout [String: Double], from importances: [String: Double]) {
    for (feature, value) in importances {
      combined[feature] = max(combined[feature] ?? 0.0, value)
    }
    if let maximum = combined.values.max(), maximum > 0.0 {
      for (feature, value) in combined {
        combined[feature] = value / maximum
      }
    }
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
  
  /// The predictor's models directory.
  ///
  /// - Returns: A URL.
  private func modelsDirectory() -> URL {
    let fileContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return fileContainerURL.appendingPathComponent("models")
  }
  
}
#endif
