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
    static let currentPressure = "Current Pressure"
    static let currentHumidity = "Current Humidity"
    static let currentTemperature = "Current Temperature"
    static let sigmaPressure = "Sigma Pressure"
    static let sigmaHumidity = "Sigma Humidity"
    static let sigmaTemperature = "Sigma Temperature"
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
  
  /// Current Pressure as double value
  var Current_Pressure: Double
  
  /// Current Humidity as double value
  var Current_Humidity: Double
  
  /// Current Temperature as double value
  var Current_Temperature: Double
  
  /// Sigma Pressure as double value
  var Sigma_Pressure: Double
  
  /// Sigma Humidity as double value
  var Sigma_Humidity: Double
  
  /// Sigma Temperature as double value
  var Sigma_Temperature: Double
  
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
        FeatureName.currentPressure,
        FeatureName.currentHumidity,
        FeatureName.currentTemperature,
        FeatureName.sigmaPressure,
        FeatureName.sigmaHumidity,
        FeatureName.sigmaTemperature,
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
    if (featureName == FeatureName.currentPressure) {
      return MLFeatureValue(double: Current_Pressure)
    }
    if (featureName == FeatureName.currentHumidity) {
      return MLFeatureValue(double: Current_Humidity)
    }
    if (featureName == FeatureName.currentTemperature) {
      return MLFeatureValue(double: Current_Temperature)
    }
    if (featureName == FeatureName.sigmaPressure) {
      return MLFeatureValue(double: Sigma_Pressure)
    }
    if (featureName == FeatureName.sigmaHumidity) {
      return MLFeatureValue(double: Sigma_Humidity)
    }
    if (featureName == FeatureName.sigmaTemperature) {
      return MLFeatureValue(double: Sigma_Temperature)
    }
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
  
  convenience init(weather: Weather?, healthKitData: [HealthKitData: Double], date: Date) {
    self.init(
      Current_Pressure: weather?.currentPressure.converted(to: .kilopascals).value ?? 0.0,
      Current_Humidity: weather?.currentHumidity ?? 0.0,
      Current_Temperature: weather?.currentTemperature.converted(to: .celsius).value ?? 0.0,
      Sigma_Pressure: weather?.sigmaPressure ?? 0.0,
      Sigma_Humidity: weather?.sigmaHumidity ?? 0.0,
      Sigma_Temperature: weather?.sigmaTemperature ?? 0.0,
      Barometric_Pressure: weather?.devicePressure.converted(to: .kilopascals).value ?? 0.0,
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
  
  init(Current_Pressure: Double, Current_Humidity: Double, Current_Temperature: Double, Sigma_Pressure: Double, Sigma_Humidity: Double, Sigma_Temperature: Double, Barometric_Pressure: Double, Heart_Rate: Double, Mindful_Session: Double, Sleep_Analysis: Double, Respiratory_Rate: Double, Oxygen_Saturation: Double, Heart_Rate_Variability: Double, Walking_Heart_Rate_Average: Double, Resting_Heart_Rate: Double, Headphone_Audio_Exposure: Double, Environment_Audio_Exposure: Double, Step_Count: Double, Seconds_Since_Midnight: Double, Weekday: Double, timestamp: Date) {
    self.Current_Pressure = Current_Pressure
    self.Current_Humidity = Current_Humidity
    self.Current_Temperature = Current_Temperature
    self.Sigma_Pressure = Sigma_Pressure
    self.Sigma_Humidity = Sigma_Humidity
    self.Sigma_Temperature = Sigma_Temperature
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
