//
//  Predictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import ApplicationKey
import CoreML
import Foundation
import WidgetKit

#if NON_PREVIEW
import CreateML

class Predictor: ObservableObject {
  
  // MARK: Types
  
  enum ModelType {
    case durationRegressor
    case onsetRegressor
    case outlookClassifier
    case severityClassifier
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
  
  // MARK: Private properties
  
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
  
  /// Whether or not training was cancelled.
  private var cancelledTraining = false
  
  /// The metadata to save with a model.
  private let metadata = MLModelMetadata(
    author: "Colin Campbell",
    shortDescription: "Predicts the onset, severity and progression of headaches.",
    version: Date().description)
  
  /// The prediction observer.
  private var predictionObserver: NSObjectProtocol?
  
  // MARK: Initializers
  
  init() {
    predictionObserver = SharedUserDefaults.preferences.addPredictionObserver(using: predictionNotification)
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
      SharedUserDefaults.preferences.removePredictionObserver(predictionObserver)
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
    cancelledTraining = true
  }
  
  /// Resets the predictor and its classifiers.
  func reset() {
    do {
      // Delete the compiled models
      try FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.outlookClassifierFileName))
      try FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.severityClassifierFileName))
      try FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.onsetRegressorFileName))
      try FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.durationRegressorFileName))
      severityClassifier = nil
      
      // Reset the rest of our variables
      modelUpdatedAt = nil
    }
    catch {
      logError("Error resetting predictor: \(error)")
    }
    
    DispatchQueue.main.async { self.ready = false }
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
          let fullInput = input.fullInput()
          let outlookPrediction = try outlookClassifier.prediction(input: fullInput)
          let severityPrediction = try severityClassifier.prediction(input: fullInput)
          let onsetPrediction = try onsetRegressor.prediction(input: fullInput)
          let durationPrediction = try durationRegressor.prediction(input: fullInput)
          
          let prediction = PredictionOutput(
            input: input,
            
            outlookClassifierOutput: PredictionOutput.PredictionStatistic(
              prediction: Outlook(rawValue: outlookPrediction.Outlook) ?? .noHeadache,
              probability: outlookPrediction.OutlookProbability[outlookPrediction.Outlook]),
            
            severityClassifierOutput: PredictionOutput.PredictionStatistic(
              prediction: Headache.Severity(title: severityPrediction.Severity)!,
              probability: severityPrediction.SeverityProbability[severityPrediction.Severity]),
            
            onsetRegressorOutput: PredictionOutput.PredictionStatistic<Date>(
              prediction: Date().addingTimeInterval(onsetPrediction.Onset),
              probability: nil),
            
            durationRegressorOutput: PredictionOutput.PredictionStatistic<TimeInterval>(
              prediction: durationPrediction.Duration,
              probability: nil)
          )
          
          // Update the prediction value
          DispatchQueue.main.async {
            self.prediction = prediction
          }
          
          // Save this prediction for the widget
          SharedUserDefaults.preferences.setCurrentPrediction(prediction, inWidget: inWidget)
          
          continuation.resume(returning: prediction)
        }
        catch {
          continuation.resume(throwing: error)
        }
      }
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
    DispatchQueue.main.async {
      self.prediction = SharedUserDefaults.preferences.currentPrediction
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
        
        completion(nil)
        DispatchQueue.main.async {
          self.modelLoadedAt = Date()
          self.ready = true
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
    guard !training && input.isValid else {
      logDebug("Training data is not valid.")
      completion(nil)
      return
    }
        
    DispatchQueue.main.async { [weak self] in self?.training = true }
    cancelledTraining = false
    
    let finished: (Error?) -> Void = { [weak self] error in
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
        
        // Train the outlook classifier
        if !self.cancelledTraining {
          logDebug("Training outlook classifier.")
          // Train the classifier
          let classifier = try MLBoostedTreeClassifier(trainingData: input.outlookTable, targetColumn: OutlookClassifierOutput.FeatureName.outlook)
          
          // Write the trained model to file
          try self.writeModel(classifier, toFileWithName: Predictor.outlookClassifierFileName)
        }
        
        // Train the severity classifier
        if !self.cancelledTraining {
          logDebug("Training severity classifier.")
          // Train the classifier
          let classifier = try MLBoostedTreeClassifier(trainingData: input.severityTable, targetColumn: SeverityClassifierOutput.FeatureName.severity)
          
          // Write the trained model to file
          try self.writeModel(classifier, toFileWithName: Predictor.severityClassifierFileName)
        }
        
        // Train the onset regressor
        if !self.cancelledTraining {
          logDebug("Training onset regressor.")
          // Train the regressor
          let regressor = try MLBoostedTreeRegressor(trainingData: input.onsetTable, targetColumn: OnsetRegressorOutput.FeatureName.onset)
          
          // Write the trained model to file
          try self.writeModel(regressor, toFileWithName: Predictor.onsetRegressorFileName)
        }
        
        // Train the duration regressor
        if !self.cancelledTraining {
          logDebug("Training duration regressor.")
          // Train the regressor
          let regressor = try MLBoostedTreeRegressor(trainingData: input.durationTable, targetColumn: DurationRegressorOutput.FeatureName.duration)
          
          // Write the trained model to file
          try self.writeModel(regressor, toFileWithName: Predictor.durationRegressorFileName)
        }
        
        logDebug("Getting creation date.")
        if let creationDate = try self.dateOfFile(at: self.compiledModelURL(with: Predictor.outlookClassifierFileName)) {
          logDebug("Got creation date: \(creationDate.description)")
          DispatchQueue.main.async { self.modelUpdatedAt = creationDate }
        }
        else {
          logWarning("Unable to get recent model creation date.")
        }
        
        if self.cancelledTraining {
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
  
  /// Writes the model to the file with the given model name.
  ///
  /// - Parameters:
  ///   - model: The model to write to file.
  ///   - fileName: The filename to use.
  private func writeModel<T: CoreMLModel>(_ model: T, toFileWithName fileName: String) throws {
    // Write the trained model to file
    let modelURL = modelURL(with: fileName)
    try model.write(to: modelURL, metadata: metadata)
    
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
  /// - Returns: The file's creation date.
  private func dateOfFile(at url: URL) throws -> Date? {
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
  
  /// The predictor's models directory.
  ///
  /// - Returns: A URL.
  private func modelsDirectory() -> URL {
    let fileContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return fileContainerURL.appendingPathComponent("models")
  }
  
}
#endif
