//
//  PredictionOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

/// A headache prediction.
struct PredictionOutput: Equatable, Codable {
  
  /// An empty prediction.
  static let empty = PredictionOutput(
    input: .empty,
    outlookClassifierOutput: PredictionStatistic<Outlook>(prediction: .noHeadache, probability: 0),
    severityClassifierOutput: PredictionStatistic<Headache.Severity>(prediction: .notPresent, probability: 0),
    onsetRegressorOutput: PredictionStatistic<Date>(prediction: Date(timeIntervalSince1970: 0), probability: nil),
    durationRegressorOutput: PredictionStatistic<TimeInterval>(prediction: 0, probability: nil),
    date: Date(timeIntervalSinceNow: -600.0))
  
  /// A prediction statistic pairs a severity to a probability.
  struct PredictionStatistic<T: Equatable & Codable>: Equatable, Codable {
    
    /// The statistic's severity.
    var prediction: T
    
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
  
  /// The model input that generated this prediction.
  var input: ModelInput
  
  /// The outlook classifier's output
  var outlookClassifierOutput: PredictionStatistic<Outlook>
  
  /// The severity classifier's output.
  var severityClassifierOutput: PredictionStatistic<Headache.Severity>
  
  /// The onset regressor's output.
  var onsetRegressorOutput: PredictionStatistic<Date>
  
  /// The duration regressor's output.
  var durationRegressorOutput: PredictionStatistic<TimeInterval>
  
  /// The date of this prediction.
  var date = Date()
  
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
