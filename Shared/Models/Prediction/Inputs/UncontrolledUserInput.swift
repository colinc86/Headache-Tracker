//
//  UncontrolledUserInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import CoreML
import SwiftUI

class UncontrolledUserInput: MLFeatureProvider {
  
  struct FeatureName {
    static let heartRate = "Heart Rate"
    static let respiratoryRate = "Respiratory Rate"
    static let oxygenSaturation = "Oxygen Saturation"
    static let heartRateVariability = "Heart Rate Variability"
    static let walkingHeartRateAverage = "Walking Heart Rate Average"
    static let restingHeartRate = "Resting Heart Rate"
  }
  
  let preferences = Preferences.Predictors()
  
  /// Heart Rate as double value
  var Heart_Rate: Double
  
  /// Respiratory Rate as double value
  var Respiratory_Rate: Double
  
  /// Oxygen Saturation as double value
  var Oxygen_Saturation: Double
  
  /// Heart Rate Variability as double value
  var Heart_Rate_Variability: Double
  
  /// Walking Heart Rate Average as double value
  var Walking_Heart_Rate_Average: Double
  
  /// Resting Heart Rate as double value
  var Resting_Heart_Rate: Double
  
  var featureNames: Set<String> {
    get {
      var names = Set<String>()
      if preferences.heartRate == true {
        names.insert(FeatureName.heartRate)
      }
      if preferences.respiratoryRate == true {
        names.insert(FeatureName.respiratoryRate)
      }
      if preferences.oxygenSaturation == true {
        names.insert(FeatureName.oxygenSaturation)
      }
      if preferences.heartRateVariability == true {
        names.insert(FeatureName.heartRateVariability)
      }
      if preferences.walkingHeartRateAverage == true {
        names.insert(FeatureName.walkingHeartRateAverage)
      }
      if preferences.restingHeartRate == true {
        names.insert(FeatureName.restingHeartRate)
      }
      return names
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.heartRate) {
      return MLFeatureValue(double: Heart_Rate)
    }
    if (featureName == FeatureName.respiratoryRate) {
      return MLFeatureValue(double: Respiratory_Rate)
    }
    if (featureName == FeatureName.oxygenSaturation) {
      return MLFeatureValue(double: Oxygen_Saturation)
    }
    if (featureName == FeatureName.heartRateVariability) {
      return MLFeatureValue(double: Heart_Rate_Variability)
    }
    if (featureName == FeatureName.walkingHeartRateAverage) {
      return MLFeatureValue(double: Walking_Heart_Rate_Average)
    }
    if (featureName == FeatureName.restingHeartRate) {
      return MLFeatureValue(double: Resting_Heart_Rate)
    }
    return nil
  }
  
  convenience init(healthKitData: [HealthKitData: Double]?) {
    self.init(
      Heart_Rate: healthKitData?[HealthKitData.heartRate] ?? 0.0,
      Respiratory_Rate: healthKitData?[HealthKitData.respiratoryRate] ?? 0.0,
      Oxygen_Saturation: healthKitData?[HealthKitData.oxygenSaturation] ?? 0.0,
      Heart_Rate_Variability: healthKitData?[HealthKitData.heartRateVariabilitySDNN] ?? 0.0,
      Walking_Heart_Rate_Average: healthKitData?[HealthKitData.walkingHeartRateAverage] ?? 0.0,
      Resting_Heart_Rate: healthKitData?[HealthKitData.restingHeartRate] ?? 0.0
    )
  }
  
  init(Heart_Rate: Double, Respiratory_Rate: Double, Oxygen_Saturation: Double, Heart_Rate_Variability: Double, Walking_Heart_Rate_Average: Double, Resting_Heart_Rate: Double) {
    self.Heart_Rate = Heart_Rate
    self.Respiratory_Rate = Respiratory_Rate
    self.Oxygen_Saturation = Oxygen_Saturation
    self.Heart_Rate_Variability = Heart_Rate_Variability
    self.Walking_Heart_Rate_Average = Walking_Heart_Rate_Average
    self.Resting_Heart_Rate = Resting_Heart_Rate
  }
  
}
