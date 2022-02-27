//
//  ControlledUserInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML

class ControlledUserInput: MLFeatureProvider {
  
  struct FeatureName {
    static let mindfulSession = "Mindful Session"
    static let sleepAnalysis = "Sleep Analysis"
    static let headphoneAudioExposure = "Headphone Audio Exposure"
    static let stepCount = "Step Count"
  }
  
  /// Mindful Session as double value
  var Mindful_Session: Double
  
  /// Sleep Analysis as double value
  var Sleep_Analysis: Double
  
  /// Headphone Audio Exposure as double value
  var Headphone_Audio_Exposure: Double
  
  /// Step Count as double value
  var Step_Count: Double
  
  var featureNames: Set<String> {
    get {
      return [
        FeatureName.mindfulSession,
        FeatureName.sleepAnalysis,
        FeatureName.headphoneAudioExposure,
        FeatureName.stepCount
      ]
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.mindfulSession) {
      return MLFeatureValue(double: Mindful_Session)
    }
    if (featureName == FeatureName.sleepAnalysis) {
      return MLFeatureValue(double: Sleep_Analysis)
    }
    if (featureName == FeatureName.headphoneAudioExposure) {
      return MLFeatureValue(double: Headphone_Audio_Exposure)
    }
    if (featureName == FeatureName.stepCount) {
      return MLFeatureValue(double: Step_Count)
    }
    return nil
  }
  
  convenience init(healthKitData: [HealthKitData: Double]) {
    self.init(
      Mindful_Session: healthKitData[HealthKitData.mindfulSession] ?? 0.0,
      Sleep_Analysis: healthKitData[HealthKitData.sleepAnalysis] ?? 0.0,
      Headphone_Audio_Exposure: healthKitData[HealthKitData.headphoneAudioExposure] ?? 0.0,
      Step_Count: healthKitData[HealthKitData.stepCount] ?? 0.0
    )
  }
  
  init(Mindful_Session: Double, Sleep_Analysis: Double, Headphone_Audio_Exposure: Double, Step_Count: Double) {
    self.Mindful_Session = Mindful_Session
    self.Sleep_Analysis = Sleep_Analysis
    self.Headphone_Audio_Exposure = Headphone_Audio_Exposure
    self.Step_Count = Step_Count
  }
  
}
