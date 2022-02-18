//
//  Predictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import ApplicationKey
import CoreML
import Foundation
import Logger
import HealthKit

#if NON_PREVIEW
import CreateML
#endif

class Predictor: ObservableObject {
  
  // MARK: Types
  
  /// A headache prediction.
  struct Prediction {
    
    /// An empty prediction.
    static let empty = Prediction(severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>(prediction: .notPresent, probability: 0.0))
    
    /// A prediction statistic pairs a severity to a probability.
    struct PredictionStatistic<T> {
      
      /// The statistic's severity.
      let prediction: T
      
      /// The statistic's probability.
      let probability: Double
      
      // MARK: Initializers
      
      init(prediction: T, probability: Double) {
        self.prediction = prediction
        self.probability = probability
      }
    }
    
    /// The severity classifier's output.
    let severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>
    
  }
  
  // MARK: Static properties
  
  /// The filename to use for the severity classifier.
  private static let severityClassifierFileName = "sc"
  
  // MARK: Public properties
  
  /// Whether or not the predictor is training.
  @Published var training: Bool = false
  
  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?
  
  // MARK: Private properties
  
  /// The classifier for predicting headache severities.
  private var severityClassifier: Model<SeverityClassifierInput, SeverityClassifierOutput>?
  
  /// The queue to do anything with models on.
  private var modelQueue = DispatchQueue(label: ApplicationKey(from: "modelQueue"))
  
  /// The training background task.
  private var trainingBackgroundTask = BackgroundTask(identifier: "training")
  
  /// Whether or not training was cancelled.
  private var cancelledTraining = false
  
#if NON_PREVIEW
  /// The metadata to save with a model.
  private let metadata = MLModelMetadata(
    author: "Colin Campbell",
    shortDescription: "Predicts the onset, severity and progression of headaches.",
    version: Date().description)
#endif
  
}

// MARK: Public methods

extension Predictor {
  
  /// Loads the predictor's models.
  ///
  /// - Parameter completion: Called after the models have been loaded.
  func load(_ completion: @escaping (Error?) -> Void) {
    logDebug("Load models.")
    
    modelQueue.async { [weak self] in
      guard let self = self else {
        completion(nil)
        return
      }
      
      do {
        logDebug("Loading severity classifier.")
        let severityClassifierModelURL = self.compiledModelURL(with: Predictor.severityClassifierFileName)
        self.severityClassifier = try Model<SeverityClassifierInput, SeverityClassifierOutput>(contentsOf: severityClassifierModelURL)
        
        logDebug("Getting creation date.")
        if let creationDate = try self.trainingDateOfCompiledModel(at: severityClassifierModelURL) {
          logDebug("Got creation date: \(creationDate.description)")
          DispatchQueue.main.async { self.modelUpdatedAt = creationDate }
        }
        else {
          logWarning("Unable to get recent model creation date.")
        }
        
        completion(nil)
        DispatchQueue.main.async { self.ready = true }
      }
      catch {
        completion(error)
        DispatchQueue.main.async { self.ready = false }
      }
    }
  }
  
  /// Trains the predictor's classifiers.
  ///
  /// - Parameters:
  ///   - trainingData: The training data.
  ///   - completion: Called after training has completed.
  func train(with trainingData: [TrainingData], completion: @escaping (Error?) -> Void) {
    guard !training && !trainingData.isEmpty else {
      completion(nil)
      return
    }
    
    logDebug("Train with \(trainingData.count) training data.")
    trainingBackgroundTask.begin(expired: cancelTraining)
    
    DispatchQueue.main.async { [weak self] in self?.training = true }
    cancelledTraining = false
    
    let finished: (Error?) -> Void = { [weak self] error in
      completion(error)
      DispatchQueue.main.async { self?.training = false }
      self?.trainingBackgroundTask.end()
      return
    }
    
#if NON_PREVIEW
    // Get the data table
    let table: MLDataTable
    do {
      table = try MLDataTable(dictionary: trainingData.dataTable())
    }
    catch {
      logError("Error creating data table: \(error)")
      finished(error)
      return
    }
    logDebug("Got table: \(table)")
    
    // Train the models
    modelQueue.async { [weak self] in
      do {
        guard let self = self else {
          finished(nil)
          return
        }
        
        // Train the severity classifier
        if !self.cancelledTraining {
          logDebug("Training severity classifier.")
          // Train the classifier
          let classifier = try MLBoostedTreeClassifier(trainingData: table, targetColumn: SeverityClassifierOutput.FeatureName.severity)
          
          // Write the trained model to file
          let modelURL = self.modelURL(with: Predictor.severityClassifierFileName)
          try classifier.write(to: modelURL, metadata: self.metadata)
          
          // Compile the model
          let newCompiledModelURL = try MLModel.compileModel(at: modelURL)
          
          // Replace the old compiled model with the new one
          let compiledModelURL = self.compiledModelURL(with: Predictor.severityClassifierFileName)
          _ = try FileManager.default.replaceItemAt(compiledModelURL, withItemAt: newCompiledModelURL)
          
          // Remove the pre-compiled model
          try FileManager.default.removeItem(at: modelURL)
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
#else
    finished(nil)
#endif
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
      try FileManager.default.removeItem(at: self.compiledModelURL(with: Predictor.severityClassifierFileName))
      severityClassifier = nil
      
      // Reset the rest of our variables
      modelUpdatedAt = nil
    }
    catch {
      logError("Error resetting predictor: \(error)")
    }
    
    DispatchQueue.main.async { self.ready = false }
  }
  
  /// Makes a prediction.
  ///
  /// - Parameter input: The predictor's input.
  /// - Returns: The predictor's output.
  func predict(_ input: SeverityClassifierInput) throws -> Prediction {
    guard let severityClassifier = severityClassifier else {
      return .empty
    }
    
    let severityPrediction = try severityClassifier.prediction(input: input)
    
    return Prediction(
      severityClassifierOutput: Prediction.PredictionStatistic(
        prediction: HKCategoryValueSeverity(title: severityPrediction.Severity)!,
        probability: severityPrediction.SeverityProbability[severityPrediction.Severity] ?? 0.0))
  }
  
}

extension Predictor {
  
  /// The compilation date of the compiled model file with the given url.
  ///
  /// - Parameter url: The url of the model.
  /// - Returns: The file's creation date.
  private func trainingDateOfCompiledModel(at url: URL) throws -> Date? {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return attributes[.modificationDate] as? Date ?? attributes[.creationDate] as? Date
  }
  
  /// The URL of a model with the given name.
  ///
  /// - Parameter name: The name of the model.
  /// - Returns: The URL of the model.
  private func modelURL(with name: String) -> URL {
    return documentsDirectory().appendingPathComponent("models").appendingPathComponent("\(name).mlmodel")
  }
  
  /// The URL of a compiled model with the given name.
  ///
  /// - Parameter name: The name of the compiled model.
  /// - Returns: The URL of the compiled model.
  private func compiledModelURL(with name: String) -> URL {
    return documentsDirectory().appendingPathComponent("models").appendingPathComponent("\(name).mlmodelc")
  }
  
  /// The application's document's directory.
  ///
  /// - Returns: A URL.
  private func documentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }
  
}
