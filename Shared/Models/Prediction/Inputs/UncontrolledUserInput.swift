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
    static let bodyTemperature = "Body Temperature"
    static let wristTemperature = "Wrist Temperature"
    static let basalBodyTemperature = "Basal Body Temperature"
    static let menstrualDaysSinceCycleStart = "Menstrual Days Since Cycle Start"
    static let menstrualFlowActive = "Menstrual Flow Active"
    static let hrvRMSSD = "HRV RMSSD"
    static let hrvPNN50 = "HRV pNN50"
    static let hrvLFHF = "HRV LF HF"
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

  /// Body (skin) temperature in degrees Celsius.
  var Body_Temperature: Double

  /// Sleeping wrist temperature in degrees Celsius.
  var Wrist_Temperature: Double

  /// Basal body temperature in degrees Celsius.
  var Basal_Body_Temperature: Double

  /// Days since the start of the current menstrual cycle.
  var Menstrual_Days_Since_Cycle_Start: Double

  /// Whether menstrual flow is active (1) or not (0).
  var Menstrual_Flow_Active: Double

  /// Beat-to-beat HRV: root mean square of successive differences (ms).
  var HRV_RMSSD: Double

  /// Beat-to-beat HRV: proportion of successive differences over 50 ms.
  var HRV_pNN50: Double

  /// Beat-to-beat HRV: low- to high-frequency power ratio.
  var HRV_LF_HF: Double

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
      if preferences.bodyTemperature == true {
        names.insert(FeatureName.bodyTemperature)
      }
      if preferences.wristTemperature == true {
        names.insert(FeatureName.wristTemperature)
      }
      if preferences.basalBodyTemperature == true {
        names.insert(FeatureName.basalBodyTemperature)
      }
      if preferences.menstrualCycle == true {
        names.insert(FeatureName.menstrualDaysSinceCycleStart)
        names.insert(FeatureName.menstrualFlowActive)
      }
      if preferences.beatToBeatHRV == true {
        names.insert(FeatureName.hrvRMSSD)
        names.insert(FeatureName.hrvPNN50)
        names.insert(FeatureName.hrvLFHF)
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
    if (featureName == FeatureName.bodyTemperature) {
      return MLFeatureValue(double: Body_Temperature)
    }
    if (featureName == FeatureName.wristTemperature) {
      return MLFeatureValue(double: Wrist_Temperature)
    }
    if (featureName == FeatureName.basalBodyTemperature) {
      return MLFeatureValue(double: Basal_Body_Temperature)
    }
    if (featureName == FeatureName.menstrualDaysSinceCycleStart) {
      return MLFeatureValue(double: Menstrual_Days_Since_Cycle_Start)
    }
    if (featureName == FeatureName.menstrualFlowActive) {
      return MLFeatureValue(double: Menstrual_Flow_Active)
    }
    if (featureName == FeatureName.hrvRMSSD) {
      return MLFeatureValue(double: HRV_RMSSD)
    }
    if (featureName == FeatureName.hrvPNN50) {
      return MLFeatureValue(double: HRV_pNN50)
    }
    if (featureName == FeatureName.hrvLFHF) {
      return MLFeatureValue(double: HRV_LF_HF)
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
      Resting_Heart_Rate: healthKitData?[HealthKitData.restingHeartRate] ?? 0.0,
      Body_Temperature: healthKitData?[HealthKitData.bodyTemperature] ?? 0.0,
      Wrist_Temperature: healthKitData?[HealthKitData.wristTemperature] ?? 0.0,
      Basal_Body_Temperature: healthKitData?[HealthKitData.basalBodyTemperature] ?? 0.0,
      Menstrual_Days_Since_Cycle_Start: healthKitData?[HealthKitData.menstrualDaysSinceCycleStart] ?? 0.0,
      Menstrual_Flow_Active: healthKitData?[HealthKitData.menstrualFlowActive] ?? 0.0,
      HRV_RMSSD: healthKitData?[HealthKitData.hrvRMSSD] ?? 0.0,
      HRV_pNN50: healthKitData?[HealthKitData.hrvPNN50] ?? 0.0,
      HRV_LF_HF: healthKitData?[HealthKitData.hrvLFHF] ?? 0.0
    )
  }

  init(Heart_Rate: Double, Respiratory_Rate: Double, Oxygen_Saturation: Double, Heart_Rate_Variability: Double, Walking_Heart_Rate_Average: Double, Resting_Heart_Rate: Double, Body_Temperature: Double, Wrist_Temperature: Double, Basal_Body_Temperature: Double, Menstrual_Days_Since_Cycle_Start: Double, Menstrual_Flow_Active: Double, HRV_RMSSD: Double, HRV_pNN50: Double, HRV_LF_HF: Double) {
    self.Heart_Rate = Heart_Rate
    self.Respiratory_Rate = Respiratory_Rate
    self.Oxygen_Saturation = Oxygen_Saturation
    self.Heart_Rate_Variability = Heart_Rate_Variability
    self.Walking_Heart_Rate_Average = Walking_Heart_Rate_Average
    self.Resting_Heart_Rate = Resting_Heart_Rate
    self.Body_Temperature = Body_Temperature
    self.Wrist_Temperature = Wrist_Temperature
    self.Basal_Body_Temperature = Basal_Body_Temperature
    self.Menstrual_Days_Since_Cycle_Start = Menstrual_Days_Since_Cycle_Start
    self.Menstrual_Flow_Active = Menstrual_Flow_Active
    self.HRV_RMSSD = HRV_RMSSD
    self.HRV_pNN50 = HRV_pNN50
    self.HRV_LF_HF = HRV_LF_HF
  }
  
}
