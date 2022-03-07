//
//  Predictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import ApplicationKey
import CoreML
import Foundation
import HealthKit
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
  
  struct TrainingInput {
    
    let outlookTable: MLDataTable
    let severityTable: MLDataTable
    let onsetTable: MLDataTable
    let durationTable: MLDataTable
    
    var isValid: Bool {
      return outlookTable.isValid && outlookTable.isValid && onsetTable.isValid && durationTable.isValid
    }
    
    init(trainingData: [TrainingData]) throws {
      // Set the training tags
      trainingData.setVolitileVariables()
      
      // Get the data tables
      outlookTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .outlookClassifier).outlookDataTable())
      severityTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .severityClassifier).severityDataTable())
      onsetTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .onsetRegressor).onsetTableData())
      durationTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .durationRegressor).durationTableData())
    }
    
    /// Balances the training data for the given model type.
    ///
    /// - Parameters:
    ///   - trainingData: The training data to balance.
    ///   - modelType: The model type intended to train.
    /// - Returns: The training data.
    private static func balanceTrainingData(_ trainingData: [TrainingData], forModelType modelType: ModelType) -> [TrainingData] {
      switch modelType {
      case .durationRegressor:
        return trainingData.filter({ $0.timeIntervalUntilNextHeadacheEnd != nil })
      case .onsetRegressor:
        return trainingData.filter({ $0.timeIntervalUntilNextHeadacheStart != nil })
      case .severityClassifier:
        var headacheData = trainingData.filter({ $0.severity?.headache != nil })
        var nonHeadacheData = trainingData.filter({ $0.severity?.headache == nil })
        
        // Min count
        let minCount = min(headacheData.count, nonHeadacheData.count)
        
        // Shuffle
        headacheData.shuffle()
        nonHeadacheData.shuffle()
        
        // Trim
        if headacheData.count > minCount {
          headacheData = [TrainingData](headacheData[0 ..< minCount])
        }
        if nonHeadacheData.count > minCount {
          nonHeadacheData = [TrainingData](nonHeadacheData[0 ..< minCount])
        }
        
        return headacheData + nonHeadacheData
      case .outlookClassifier:
        var headacheData = trainingData.filter({ $0.outlook == .headache })
        var possibleHeadacheData = trainingData.filter({ $0.outlook == .possibleHeadache })
        var noHeadacheData = trainingData.filter({ $0.outlook == .noHeadache })
        
        // Min count
        let minCount = min(headacheData.count, possibleHeadacheData.count, noHeadacheData.count)
        
        // Shuffle
        headacheData.shuffle()
        possibleHeadacheData.shuffle()
        noHeadacheData.shuffle()
        
        // Trim
        if headacheData.count > minCount {
          headacheData = [TrainingData](headacheData[0 ..< minCount])
        }
        if possibleHeadacheData.count > minCount {
          possibleHeadacheData = [TrainingData](possibleHeadacheData[0 ..< minCount])
        }
        if noHeadacheData.count > minCount {
          noHeadacheData = [TrainingData](noHeadacheData[0 ..< minCount])
        }
        
        return headacheData + possibleHeadacheData + noHeadacheData
      }
    }
  }
  
  /// A prediction input.
  struct Input {
    
    /// The input weather data.
    var weather: Weather?
    
    /// The input health kit data.
    var healthKitData: [HealthKitData: Double]?
    
    /// The input date.
    var date: Date
    
    /// The full model input.
    func fullInput() -> InputUnion {
      return InputUnion(providers: [controlledUserInput(), environmentalInput(), timeInput(), uncontrolledUserInput()])
    }
    
    private func controlledUserInput() -> ControlledUserInput {
      return ControlledUserInput(healthKitData: healthKitData ?? [:])
    }
    
    private func environmentalInput() -> EnvironmentalInput {
      return EnvironmentalInput(weather: weather, healthKitData: healthKitData ?? [:])
    }
    
    private func timeInput() -> TimeInput {
      return TimeInput(date: date)
    }
    
    private func uncontrolledUserInput() -> UncontrolledUserInput {
      return UncontrolledUserInput(healthKitData: healthKitData ?? [:])
    }
    
  }
  
  /// A headache prediction.
  struct Prediction: Equatable {
    
    /// An empty prediction.
    static let empty = Prediction(
      outlookClassifierOutput: PredictionStatistic<Outlook>(prediction: .noHeadache, probability: 0),
      severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>(prediction: .notPresent, probability: 0),
      onsetRegressorOutput: PredictionStatistic<Date>(prediction: Date(timeIntervalSince1970: 0), probability: nil),
      durationRegressorOutput: PredictionStatistic<TimeInterval>(prediction: 0, probability: nil))
    
    /// A prediction statistic pairs a severity to a probability.
    struct PredictionStatistic<T: Equatable>: Equatable {
      
      /// The statistic's severity.
      let prediction: T
      
      /// The statistic's probability.
      let probability: Double?
      
      // MARK: Initializers
      
      init(prediction: T, probability: Double?) {
        self.prediction = prediction
        self.probability = probability
      }
      
      static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.prediction == rhs.prediction && lhs.probability == rhs.probability
      }
    }
    
    /// The outlook classifier's output
    let outlookClassifierOutput: PredictionStatistic<Outlook>
    
    /// The severity classifier's output.
    let severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>
    
    /// The onset regressor's output.
    let onsetRegressorOutput: PredictionStatistic<Date>
    
    /// The duration regressor's output.
    let durationRegressorOutput: PredictionStatistic<TimeInterval>
    
    /// The date of this prediction.
    let date = Date()
    
    /// The prediction's holistic outlook.
    var holisticOutlook: HolisticOutlook {
      return HolisticOutlook(
        outlook: outlookClassifierOutput.prediction,
        onset: onsetRegressorOutput.prediction,
        duration: durationRegressorOutput.prediction,
        severity: severityClassifierOutput.prediction)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      return lhs.outlookClassifierOutput == rhs.outlookClassifierOutput &&
        lhs.severityClassifierOutput == rhs.severityClassifierOutput &&
        lhs.onsetRegressorOutput == rhs.onsetRegressorOutput &&
        lhs.durationRegressorOutput == rhs.durationRegressorOutput
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
  @Published var prediction: Prediction?
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?
  
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
  
  /// Makes a prediction.
  ///
  /// - Parameters:
  ///   - input: The predictor's input.
  ///   - reloadWidget: Whether the outlook widget should be reloaded (default=true).
  /// - Returns: The predictor's output.
  @discardableResult
  func predict(_ input: Input, reloadWidget: Bool = true) async throws -> Prediction {
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
          
          let prediction = Prediction(
            outlookClassifierOutput: Prediction.PredictionStatistic(
              prediction: Outlook(rawValue: outlookPrediction.Outlook) ?? .noHeadache,
              probability: outlookPrediction.OutlookProbability[outlookPrediction.Outlook]),
            
            severityClassifierOutput: Prediction.PredictionStatistic(
              prediction: HKCategoryValueSeverity(title: severityPrediction.Severity)!,
              probability: severityPrediction.SeverityProbability[severityPrediction.Severity]),
            
            onsetRegressorOutput: Prediction.PredictionStatistic<Date>(
              prediction: Date().addingTimeInterval(onsetPrediction.Onset),
              probability: nil),
            
            durationRegressorOutput: Prediction.PredictionStatistic<TimeInterval>(
              prediction: durationPrediction.Duration,
              probability: nil)
          )
          
          /// Save this prediction for the widget
          SharedUserDefaults.standard.setPredictionResults(
            Date(),
            prediction.outlookClassifierOutput.prediction,
            prediction.onsetRegressorOutput.prediction,
            prediction.durationRegressorOutput.prediction,
            prediction.severityClassifierOutput.prediction,
            reloadWidget: reloadWidget)
          
          // Update the prediction value
          DispatchQueue.main.async {
            self.prediction = prediction
          }
          
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
#else
class Predictor: ObservableObject {
  
  // MARK: Types
  
  enum ModelType {
    case durationRegressor
    case onsetRegressor
    case outlookClassifier
    case severityClassifier
  }
  
  /// A prediction input.
  struct Input {
    
    /// The input weather data.
    var weather: Weather?
    
    /// The input health kit data.
    var healthKitData: [HealthKitData: Double]?
    
    /// The input date.
    var date: Date
    
    /// The full model input.
    func fullInput() -> InputUnion {
      return InputUnion(providers: [controlledUserInput(), environmentalInput(), timeInput(), uncontrolledUserInput()])
    }
    
    private func controlledUserInput() -> ControlledUserInput {
      return ControlledUserInput(healthKitData: healthKitData ?? [:])
    }
    
    private func environmentalInput() -> EnvironmentalInput {
      return EnvironmentalInput(weather: weather, healthKitData: healthKitData ?? [:])
    }
    
    private func timeInput() -> TimeInput {
      return TimeInput(date: date)
    }
    
    private func uncontrolledUserInput() -> UncontrolledUserInput {
      return UncontrolledUserInput(healthKitData: healthKitData ?? [:])
    }
    
  }
  
  /// A headache prediction.
  struct Prediction {
    
    /// An empty prediction.
    static let empty = Prediction()
    
    /// A prediction statistic pairs a severity to a probability.
    struct PredictionStatistic<T> {
      
      /// The statistic's severity.
      let prediction: T
      
      /// The statistic's probability.
      let probability: Double?
      
      // MARK: Initializers
      
      init(prediction: T, probability: Double?) {
        self.prediction = prediction
        self.probability = probability
      }
    }
    
    /// The outlook classifier's output
    let outlookClassifierOutput: PredictionStatistic<Outlook> = PredictionStatistic<Outlook>(prediction: .noHeadache, probability: 0)
    
    /// The severity classifier's output.
    let severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity> = PredictionStatistic<HKCategoryValueSeverity>(prediction: .notPresent, probability: 0)
    
    /// The onset regressor's output.
    let onsetRegressorOutput: PredictionStatistic<Date> = PredictionStatistic<Date>(prediction: Date(timeIntervalSince1970: 0), probability: nil)
    
    /// The duration regressor's output.
    let durationRegressorOutput: PredictionStatistic<TimeInterval> = PredictionStatistic<TimeInterval>(prediction: 0, probability: nil)
    
    /// The date of this prediction.
    let date = Date()
    
    init() {
      
    }
    
    var holisticOutlook: HolisticOutlook {
      return .noHeadache
    }
    
  }

  /// Whether or not the predictor is training.
  @Published var training: Bool = false
  
  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false
  
  /// The predictor's latest prediction.
  @Published var prediction: Prediction?
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?

}

// MARK: Public methods

extension Predictor {
  
  /// Loads the predictor's models.
  func load() async throws {}
  
  /// Trains the predictor's classifiers.
  ///
  /// - Parameter trainingData: The training data.
  func train(with trainingData: [TrainingData]) async throws {}
  
  /// Cancels the current training session.
  func cancelTraining() {}
  
  /// Resets the predictor and its classifiers.
  func reset() {}
  
  /// Makes a prediction.
  ///
  /// - Parameter input: The predictor's input.
  /// - Returns: The predictor's output.
  func predict(_ input: Input) throws -> Prediction {
    return Prediction()
  }
  
}
#endif
