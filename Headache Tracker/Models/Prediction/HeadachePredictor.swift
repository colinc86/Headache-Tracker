//
//  HeadachePredictor.swift
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

class HeadachePredictor: ObservableObject {
  
  // MARK: Types
  
  /// A headache prediction.
  struct Prediction {
    
    /// An empty prediction.
    static let empty = Prediction(
      boostedTreeOutput: .empty,
      decisionTreeOutput: .empty,
      randomForestOutput: .empty,
      logisticRegressionOutput: .empty)
    
    /// A prediction statistic pairs a severity to a probability.
    struct PredictionStatistic {
      
      /// An empty statistic.
      static let empty = PredictionStatistic(
        severity: "",
        probability: 0.0)
      
      /// The statistic's severity.
      let severity: HKCategoryValueSeverity
      
      /// The statistic's probability.
      let probability: Double
      
      /// The statistic's title.
      var title: String {
        return "\(severity.title) (\(String(format: "%0.f%%", probability * 100.0)))"
      }
      
      // MARK: Initializers
      
      init(output: HeadacheClassifierOutput) {
        self.init(
          severity: output.Severity,
          probability: output.SeverityProbability[output.Severity] ?? 0.0)
      }
      
      init(severity: String, probability: Double) {
        self.severity = HKCategoryValueSeverity(title: severity) ?? .notPresent
        self.probability = probability
      }
    }
    
    let boostedTreeOutput: PredictionStatistic
    let decisionTreeOutput: PredictionStatistic
    let randomForestOutput: PredictionStatistic
    let logisticRegressionOutput: PredictionStatistic
  }
  
  // MARK: Public properties
  
  /// Whether or not the predictor is training.
  @Published var training: Bool = false
  
  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?
  
  // MARK: Private properties
  
  private var boostedTreeClassifier: HeadacheClassifier?
  private var decisionTreeClassifier: HeadacheClassifier?
  private var randomForestClassifier: HeadacheClassifier?
  private var logisticRegressionClassifier: HeadacheClassifier?
  
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

extension HeadachePredictor {
  
  /// Loads the predictor's models.
  ///
  /// - Parameter completion: Called after the models have been loaded.
  func load(_ completion: @escaping (Error?) -> Void) {
    logDebug("Load classifiers.")
    modelQueue.async { [weak self] in
      guard let self = self else {
        completion(nil)
        return
      }
      
      do {
        logDebug("Loading boosted tree.")
        let boostedTreeModelURL = self.compiledModelURL(with: "bt")
        self.boostedTreeClassifier = try HeadacheClassifier(contentsOf: boostedTreeModelURL)
        
        logDebug("Loading decision tree.")
        self.decisionTreeClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "dt"))
        
        logDebug("Loading random forest.")
        self.randomForestClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "rf"))
        
        logDebug("Loading logistic regression.")
        self.logisticRegressionClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "lr"))
        
        logDebug("Getting creation date.")
        let attributes = try FileManager.default.attributesOfItem(atPath: boostedTreeModelURL.path)
        if let creationDate = attributes[.creationDate] as? Date {
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
    guard !training else {
      completion(nil)
      return
    }
    
    logDebug("Train with \(trainingData.count) training data.")
    trainingBackgroundTask.begin(expired: cancelTraining)
    
    DispatchQueue.main.async { [weak self] in self?.training = true }
    cancelledTraining = false
#if NON_PREVIEW
    let table: MLDataTable
    do {
      table = try MLDataTable(dictionary: trainingData.dataTable())
    }
    catch {
      logError("Error creating data table: \(error)")
      completion(error)
      return
    }
    logDebug("Got table: \(table)")
    

    modelQueue.async { [weak self] in
      do {
        guard let self = self else {
          completion(nil)
          DispatchQueue.main.async { self?.training = false }
          self?.trainingBackgroundTask.end()
          return
        }
        
        if !self.cancelledTraining {
          logDebug("Training boosted tree.")
          let btClassifier = try MLBoostedTreeClassifier(trainingData: table, targetColumn: HeadacheClassifierOutput.FeatureName.severity)
          let btModelURL = self.modelURL(with: "bt")
          try btClassifier.write(to: btModelURL, metadata: self.metadata)
          let btCompiledModelURL = try MLModel.compileModel(at: btModelURL)
          let btNewCompiledModelURL = self.compiledModelURL(with: "bt")
          if FileManager.default.isDeletableFile(atPath: btNewCompiledModelURL.path) && FileManager.default.fileExists(atPath: btNewCompiledModelURL.path) {
            try FileManager.default.removeItem(at: btNewCompiledModelURL)
          }
          try FileManager.default.moveItem(at: btCompiledModelURL, to: btNewCompiledModelURL)
          try FileManager.default.removeItem(at: btModelURL)
        }


        if !self.cancelledTraining {
          logDebug("Training decision tree.")
          let dtClassifier = try MLDecisionTreeClassifier(trainingData: table, targetColumn: HeadacheClassifierOutput.FeatureName.severity)
          let dtModelURL = self.modelURL(with: "dt")
          try dtClassifier.write(to: dtModelURL, metadata: self.metadata)
          let dtCompiledModelURL = try MLModel.compileModel(at: dtModelURL)
          let dtNewCompiledModelURL = self.compiledModelURL(with: "dt")
          if FileManager.default.isDeletableFile(atPath: dtNewCompiledModelURL.path) && FileManager.default.fileExists(atPath: dtNewCompiledModelURL.path) {
            try FileManager.default.removeItem(at: dtNewCompiledModelURL)
          }
          try FileManager.default.moveItem(at: dtCompiledModelURL, to: dtNewCompiledModelURL)
          try FileManager.default.removeItem(at: dtModelURL)
        }


        if !self.cancelledTraining {
          logDebug("Training random forest.")
          let rfClassifier = try MLRandomForestClassifier(trainingData: table, targetColumn: HeadacheClassifierOutput.FeatureName.severity)
          let rfModelURL = self.modelURL(with: "rf")
          try rfClassifier.write(to: rfModelURL, metadata: self.metadata)
          let rfCompiledModelURL = try MLModel.compileModel(at: rfModelURL)
          let rfNewCompiledModelURL = self.compiledModelURL(with: "rf")
          if FileManager.default.isDeletableFile(atPath: rfNewCompiledModelURL.path) && FileManager.default.fileExists(atPath: rfNewCompiledModelURL.path) {
            try FileManager.default.removeItem(at: rfNewCompiledModelURL)
          }
          try FileManager.default.moveItem(at: rfCompiledModelURL, to: rfNewCompiledModelURL)
          try FileManager.default.removeItem(at: rfModelURL)
        }


        if !self.cancelledTraining {
          logDebug("Training logistic regression.")
          let lrClassifier = try MLLogisticRegressionClassifier(trainingData: table, targetColumn: HeadacheClassifierOutput.FeatureName.severity)
          let lrModelURL = self.modelURL(with: "lr")
          try lrClassifier.write(to: lrModelURL, metadata: self.metadata)
          let lrCompiledModelURL = try MLModel.compileModel(at: lrModelURL)
          let lrNewCompiledModelURL = self.compiledModelURL(with: "lr")
          if FileManager.default.isDeletableFile(atPath: lrNewCompiledModelURL.path) && FileManager.default.fileExists(atPath: lrNewCompiledModelURL.path) {
            try FileManager.default.removeItem(at: lrNewCompiledModelURL)
          }
          try FileManager.default.moveItem(at: lrCompiledModelURL, to: lrNewCompiledModelURL)
          try FileManager.default.removeItem(at: lrModelURL)
        }
        
        if self.cancelledTraining {
          completion(nil)
          DispatchQueue.main.async { self.training = false }
          self.trainingBackgroundTask.end()
        }
        else {
          self.load { error in
            completion(error)
            DispatchQueue.main.async { self.training = false }
            self.trainingBackgroundTask.end()
          }
        }
      }
      catch {
        completion(error)
        DispatchQueue.main.async { self?.training = false }
        self?.trainingBackgroundTask.end()
      }
    }
#else
    completion(nil)
    DispatchQueue.main.async { [weak self] in self?.training = false }
    trainingBackgroundTask.end()
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
      boostedTreeClassifier = nil
      try FileManager.default.removeItem(at: self.compiledModelURL(with: "bt"))
      
      decisionTreeClassifier = nil
      try FileManager.default.removeItem(at: self.compiledModelURL(with: "dt"))
      
      randomForestClassifier = nil
      try FileManager.default.removeItem(at: self.compiledModelURL(with: "rf"))
      
      logisticRegressionClassifier = nil
      try FileManager.default.removeItem(at: self.compiledModelURL(with: "lr"))
      
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
  func predict(_ input: HeadacheClassifierInput) throws -> Prediction {
    guard let btClassifier = boostedTreeClassifier, let dtClassifier = decisionTreeClassifier, let rfClassifier = randomForestClassifier, let lrClassifier = logisticRegressionClassifier else {
      return .empty
    }
    
    let btPrediction = try btClassifier.prediction(input: input)
    let dtPrediction = try dtClassifier.prediction(input: input)
    let rfPrediction = try rfClassifier.prediction(input: input)
    let lrPrediction = try lrClassifier.prediction(input: input)
    
    return Prediction(
      boostedTreeOutput: Prediction.PredictionStatistic(output: btPrediction),
      decisionTreeOutput: Prediction.PredictionStatistic(output: dtPrediction),
      randomForestOutput: Prediction.PredictionStatistic(output: rfPrediction),
      logisticRegressionOutput: Prediction.PredictionStatistic(output: lrPrediction))
  }
  
}

extension HeadachePredictor {
  
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
