//
//  PredictionOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation
import HealthKit

/// A headache prediction.
struct PredictionOutput: Equatable {
  
  /// An empty prediction.
  static let empty = PredictionOutput(
    outlookClassifierOutput: PredictionStatistic<Outlook>(prediction: .noHeadache, probability: 0),
    severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>(prediction: .notPresent, probability: 0),
    onsetRegressorOutput: PredictionStatistic<Date>(prediction: Date(timeIntervalSince1970: 0), probability: nil),
    durationRegressorOutput: PredictionStatistic<TimeInterval>(prediction: 0, probability: nil))
  
  /// A prediction statistic pairs a severity to a probability.
  struct PredictionStatistic<T: Equatable>: Equatable {
    
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
  
  /// The outlook classifier's output
  var outlookClassifierOutput: PredictionStatistic<Outlook>
  
  /// The severity classifier's output.
  var severityClassifierOutput: PredictionStatistic<HKCategoryValueSeverity>
  
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
