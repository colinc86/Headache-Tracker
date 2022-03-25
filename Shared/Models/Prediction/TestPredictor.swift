//
//  TestPredictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

#if !NON_PREVIEW
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
      return InputUnion(providers: [controlledUserInput(), environmentalInput(), chronologicalInput(), uncontrolledUserInput()])
    }
    
    private func controlledUserInput() -> ControlledUserInput {
      return ControlledUserInput(healthKitData: healthKitData ?? [:])
    }
    
    private func environmentalInput() -> EnvironmentalInput {
      return EnvironmentalInput(weatherStatistics: weather?.statistics, healthKitData: healthKitData ?? [:])
    }
    
    private func chronologicalInput() -> ChronologicalInput {
      return ChronologicalInput(date: date)
    }
    
    private func uncontrolledUserInput() -> UncontrolledUserInput {
      return UncontrolledUserInput(healthKitData: healthKitData ?? [:])
    }
    
  }
  
  /// A headache prediction.
  struct Prediction: Equatable {
    
    /// An empty prediction.
    static let empty = Prediction()
    
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
    let outlookClassifierOutput: PredictionStatistic<Outlook> = PredictionStatistic<Outlook>(prediction: .noHeadache, probability: 0)
    
    /// The severity classifier's output.
    let severityClassifierOutput: PredictionStatistic<Headache.Severity> = PredictionStatistic<Headache.Severity>(prediction: .notPresent, probability: 0)
    
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
  @Published var prediction: PredictionOutput?
  
  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?
  
  init() {}
  deinit {}
  
}

// MARK: Public methods

extension Predictor {
  
  /// Loads the predictor's models.
  func load() async throws {}
  
  /// Trains the predictor's classifiers.
  ///
  /// - Parameter trainingData: The training data.
  func train(_ input: TrainingInput) async throws {}
  
  /// Cancels the current training session.
  func cancelTraining() {}
  
  /// Resets the predictor and its classifiers.
  func reset() {}
  
  func needsLoading() throws -> Bool {
    return false
  }
  
  /// Makes a prediction.
  ///
  /// - Parameter input: The predictor's input.
  /// - Returns: The predictor's output.
  func predict(_ input: ModelInput, inWidget: Bool) async throws -> PredictionOutput {
    return PredictionOutput.empty
  }
  
}
#endif
