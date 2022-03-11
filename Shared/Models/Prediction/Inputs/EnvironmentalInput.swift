//
//  EnvironmentalInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML

class EnvironmentalInput: MLFeatureProvider {
  
  struct FeatureName {
    static let currentPressure = "Current Pressure"
    static let currentHumidity = "Current Humidity"
    static let currentTemperature = "Current Temperature"
    static let sigmaPressure = "Sigma Pressure"
    static let sigmaHumidity = "Sigma Humidity"
    static let sigmaTemperature = "Sigma Temperature"
    static let environmentAudioExposure = "Environment Audio Exposure"
  }
  
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
  
  /// Environment Audio Exposure as double value
  var Environment_Audio_Exposure: Double
  
  var featureNames: Set<String> {
    get {
      return [
        FeatureName.currentPressure,
        FeatureName.currentHumidity,
        FeatureName.currentTemperature,
        FeatureName.sigmaPressure,
        FeatureName.sigmaHumidity,
        FeatureName.sigmaTemperature,
        FeatureName.environmentAudioExposure
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
    if (featureName == FeatureName.environmentAudioExposure) {
      return MLFeatureValue(double: Environment_Audio_Exposure)
    }
    return nil
  }
  
  convenience init(weatherStatistics: WeatherStatistics?, healthKitData: [HealthKitData: Double]?) {
    self.init(
      Current_Pressure: weatherStatistics?.barometricPressure ?? (weatherStatistics?.currentPressure ?? 0.0),
      Current_Humidity: weatherStatistics?.currentHumidity ?? 0.0,
      Current_Temperature: weatherStatistics?.currentTemperature ?? 0.0,
      Sigma_Pressure: weatherStatistics?.sigmaPressure ?? 0.0,
      Sigma_Humidity: weatherStatistics?.sigmaHumidity ?? 0.0,
      Sigma_Temperature: weatherStatistics?.sigmaTemperature ?? 0.0,
      Environment_Audio_Exposure: healthKitData?[HealthKitData.environmentalAudioExposure] ?? 0.0
    )
  }
  
  init(Current_Pressure: Double, Current_Humidity: Double, Current_Temperature: Double, Sigma_Pressure: Double, Sigma_Humidity: Double, Sigma_Temperature: Double, Environment_Audio_Exposure: Double) {
    self.Current_Pressure = Current_Pressure
    self.Current_Humidity = Current_Humidity
    self.Current_Temperature = Current_Temperature
    self.Sigma_Pressure = Sigma_Pressure
    self.Sigma_Humidity = Sigma_Humidity
    self.Sigma_Temperature = Sigma_Temperature
    self.Environment_Audio_Exposure = Environment_Audio_Exposure
  }
  
}
