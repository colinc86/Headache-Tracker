//
//  HeadachePredictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import ApplicationKey
import CoreML
import CreateML
import Foundation
import Logger
import HealthKit

class HeadachePredictor: ObservableObject {
  
  // MARK: Types
  
  struct Prediction {
    static let empty = Prediction(
      boostedTreeOutput: .empty,
      decisionTreeOutput: .empty,
      randomForestOutput: .empty,
      logisticRegressionOutput: .empty)
    
    struct PredictionStatistic {
      static let empty = PredictionStatistic(
        severity: "",
        probability: 0.0)
      
      let severity: HKCategoryValueSeverity
      let probability: Double
      
      var title: String {
        return "\(severity.title) (\(String(format: "%0.f%%", probability * 100.0)))"
      }
      
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
  
  @Published var loading: Bool = false
  @Published var training: Bool = false
  @Published var ready: Bool = false
  
  // MARK: Private properties
  
  private var boostedTreeClassifier: HeadacheClassifier?
  private var decisionTreeClassifier: HeadacheClassifier?
  private var randomForestClassifier: HeadacheClassifier?
  private var logisticRegressionClassifier: HeadacheClassifier?
  
  /// The queue to do anything with models on.
  private var modelQueue = DispatchQueue(label: ApplicationKey(from: "modelQueue"))
  
  /// The metadata to save with a model.
  private let metadata = MLModelMetadata(
    author: "Colin Campbell",
    shortDescription: "Predicts the onset, severity and progression of headaches.",
    version: Date().description)
  
}

// MARK: Public methods

extension HeadachePredictor {
  
  func load(_ completion: @escaping (Error?) -> Void) {
    logDebug("Load classifiers.")
    modelQueue.async { [weak self] in
      guard let self = self else {
        completion(nil)
        return
      }
      
      do {
        logDebug("Loading boosted tree.")
        self.boostedTreeClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "bt"))
        
        logDebug("Loading decision tree.")
        self.decisionTreeClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "dt"))
        
        logDebug("Loading random forest.")
        self.randomForestClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "rf"))
        
        logDebug("Loading logistic regression.")
        self.logisticRegressionClassifier = try HeadacheClassifier(contentsOf: self.compiledModelURL(with: "lr"))
        
        completion(nil)
        DispatchQueue.main.async { self.ready = true }
      }
      catch {
        completion(error)
        DispatchQueue.main.async { self.ready = false }
      }
    }
  }
  
  func train(with trainingData: [TrainingData], completion: @escaping (Error?) -> Void) {
    guard !training else {
      completion(nil)
      return
    }
    
    logDebug("Train with \(trainingData.count) training data.")
    training = true
    
    modelQueue.async { [weak self] in
      do {
        guard let self = self else {
          completion(nil)
          DispatchQueue.main.async { self?.training = false }
          return
        }
        
        let table = try MLDataTable(dictionary: trainingData.dataTable())
        logDebug("Got table: \(table)")
        
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
        
        self.load { error in
          completion(error)
          DispatchQueue.main.async { self.training = false }
        }
      }
      catch {
        completion(error)
        DispatchQueue.main.async { self?.training = false }
      }
    }
  }
  
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
    }
    catch {
      logError("Error resetting predictor: \(error)")
    }
    
    DispatchQueue.main.async { self.ready = false }
  }
  
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
  
  private func modelURL(with name: String) -> URL {
    return documentsDirectory().appendingPathComponent("models").appendingPathComponent("\(name).mlmodel")
  }
  
  private func compiledModelURL(with name: String) -> URL {
    return documentsDirectory().appendingPathComponent("models").appendingPathComponent("\(name).mlmodelc")
  }
  
  private func documentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }
  
}
