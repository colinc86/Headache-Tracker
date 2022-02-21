//
//  ModelInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import CoreML

/// Model Prediction Input Type
class ModelInput: MLFeatureProvider {
  
  struct FeatureName {
    static let barometricPressure = "Barometric Pressure"
    static let heartRate = "Heart Rate"
    static let mindfulSession = "Mindful Session"
    static let sleepAnalysis = "Sleep Analysis"
    static let respiratoryRate = "Respiratory Rate"
    static let oxygenSaturation = "Oxygen Saturation"
    static let heartRateVariability = "Heart Rate Variability"
    static let walkingHeartRateAverage = "Walking Heart Rate Average"
    static let restingHeartRate = "Resting Heart Rate"
    static let headphoneAudioExposure = "Headphone Audio Exposure"
    static let environmentAudioExposure = "Environment Audio Exposure"
    static let stepCount = "Step Count"
    static let secondsSinceMidnight = "Seconds Since Midnight"
    static let weekday = "Weekday"
  }
  
  /// The input sample's timestamp.
  /// Not directly used as input.
  var timestamp: Date
  
  /// Barometric Pressure as double value
  var Barometric_Pressure: Double
  
  /// Heart Rate as double value
  var Heart_Rate: Double
  
  /// Mindful Session as double value
  var Mindful_Session: Double
  
  /// Sleep Analysis as double value
  var Sleep_Analysis: Double
  
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
  
  /// Headphone Audio Exposure as double value
  var Headphone_Audio_Exposure: Double
  
  /// Environment Audio Exposure as double value
  var Environment_Audio_Exposure: Double
  
  /// Step Count as double value
  var Step_Count: Double
  
  /// Seconds Since Midnight as double value
  var Seconds_Since_Midnight: Double
  
  /// Weekday as double value
  var Weekday: Double
  
  var featureNames: Set<String> {
    get {
      return [
        FeatureName.barometricPressure,
        FeatureName.heartRate,
        FeatureName.mindfulSession,
        FeatureName.sleepAnalysis,
        FeatureName.respiratoryRate,
        FeatureName.oxygenSaturation,
        FeatureName.heartRateVariability,
        FeatureName.walkingHeartRateAverage,
        FeatureName.restingHeartRate,
        FeatureName.headphoneAudioExposure,
        FeatureName.environmentAudioExposure,
        FeatureName.stepCount,
        FeatureName.secondsSinceMidnight,
        FeatureName.weekday
      ]
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.barometricPressure) {
      return MLFeatureValue(double: Barometric_Pressure)
    }
    if (featureName == FeatureName.heartRate) {
      return MLFeatureValue(double: Heart_Rate)
    }
    if (featureName == FeatureName.mindfulSession) {
      return MLFeatureValue(double: Mindful_Session)
    }
    if (featureName == FeatureName.sleepAnalysis) {
      return MLFeatureValue(double: Sleep_Analysis)
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
    if (featureName == FeatureName.headphoneAudioExposure) {
      return MLFeatureValue(double: Headphone_Audio_Exposure)
    }
    if (featureName == FeatureName.environmentAudioExposure) {
      return MLFeatureValue(double: Environment_Audio_Exposure)
    }
    if (featureName == FeatureName.stepCount) {
      return MLFeatureValue(double: Step_Count)
    }
    if (featureName == FeatureName.secondsSinceMidnight) {
      return MLFeatureValue(double: Seconds_Since_Midnight)
    }
    if (featureName == FeatureName.weekday) {
      return MLFeatureValue(double: Weekday)
    }
    return nil
  }
  
  convenience init(barometricPressure: Double, healthKitData: [HealthKitData: Double], date: Date) {
    self.init(
      Barometric_Pressure: barometricPressure,
      Heart_Rate: healthKitData[HealthKitData.heartRate] ?? 0.0,
      Mindful_Session: healthKitData[HealthKitData.mindfulSession] ?? 0.0,
      Sleep_Analysis: healthKitData[HealthKitData.sleepAnalysis] ?? 0.0,
      Respiratory_Rate: healthKitData[HealthKitData.respiratoryRate] ?? 0.0,
      Oxygen_Saturation: healthKitData[HealthKitData.oxygenSaturation] ?? 0.0,
      Heart_Rate_Variability: healthKitData[HealthKitData.heartRateVariabilitySDNN] ?? 0.0,
      Walking_Heart_Rate_Average: healthKitData[HealthKitData.walkingHeartRateAverage] ?? 0.0,
      Resting_Heart_Rate: healthKitData[HealthKitData.restingHeartRate] ?? 0.0,
      Headphone_Audio_Exposure: healthKitData[HealthKitData.headphoneAudioExposure] ?? 0.0,
      Environment_Audio_Exposure: healthKitData[HealthKitData.environmentalAudioExposure] ?? 0.0,
      Step_Count: healthKitData[HealthKitData.stepCount] ?? 0.0,
      Seconds_Since_Midnight: Calendar.current.timeIntervalSinceMidnight(date),
      Weekday: Double(Calendar.current.dayOfWeek(date)),
      timestamp: date
    )
  }
  
  init(Barometric_Pressure: Double, Heart_Rate: Double, Mindful_Session: Double, Sleep_Analysis: Double, Respiratory_Rate: Double, Oxygen_Saturation: Double, Heart_Rate_Variability: Double, Walking_Heart_Rate_Average: Double, Resting_Heart_Rate: Double, Headphone_Audio_Exposure: Double, Environment_Audio_Exposure: Double, Step_Count: Double, Seconds_Since_Midnight: Double, Weekday: Double, timestamp: Date) {
    self.Barometric_Pressure = Barometric_Pressure
    self.Heart_Rate = Heart_Rate
    self.Mindful_Session = Mindful_Session
    self.Sleep_Analysis = Sleep_Analysis
    self.Respiratory_Rate = Respiratory_Rate
    self.Oxygen_Saturation = Oxygen_Saturation
    self.Heart_Rate_Variability = Heart_Rate_Variability
    self.Walking_Heart_Rate_Average = Walking_Heart_Rate_Average
    self.Resting_Heart_Rate = Resting_Heart_Rate
    self.Headphone_Audio_Exposure = Headphone_Audio_Exposure
    self.Environment_Audio_Exposure = Environment_Audio_Exposure
    self.Step_Count = Step_Count
    self.Seconds_Since_Midnight = Seconds_Since_Midnight
    self.Weekday = Weekday
    self.timestamp = timestamp
  }
  
}
