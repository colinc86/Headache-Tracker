//
//  ControlledUserInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML
import SwiftUI

class ControlledUserInput: MLFeatureProvider {
  
  struct FeatureName {
    static let mindfulSession = "Mindful Session"
    static let sleepSeconds = "Sleep Seconds"
    static let sleepOnset = "Sleep Onset"
    static let headphoneAudioExposure = "Headphone Audio Exposure"
    static let stepCount = "Step Count"
  }
  
  /// Mindful Session as double value
  var Mindful_Session: Double
  
  /// Sleep Seconds as double value
  var Sleep_Seconds: Double
  
  /// Sleep Onset as a double value
  var Sleep_Onset: Double
  
  /// Headphone Audio Exposure as double value
  var Headphone_Audio_Exposure: Double
  
  /// Step Count as double value
  var Step_Count: Double
  
  var featureNames: Set<String> {
    get {
      var names = Set<String>()
      if AppSettings.shared.predictions.mindfulSession == true {
        names.insert(FeatureName.mindfulSession)
      }
      if AppSettings.shared.predictions.sleepSeconds == true {
        names.insert(FeatureName.sleepSeconds)
      }
      if AppSettings.shared.predictions.sleepOnset == true {
        names.insert(FeatureName.sleepOnset)
      }
      if AppSettings.shared.predictions.headphoneAudioExposure == true {
        names.insert(FeatureName.headphoneAudioExposure)
      }
      if AppSettings.shared.predictions.stepCount == true {
        names.insert(FeatureName.stepCount)
      }
      return names
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.mindfulSession) {
      return MLFeatureValue(double: Mindful_Session)
    }
    if (featureName == FeatureName.sleepSeconds) {
      return MLFeatureValue(double: Sleep_Seconds)
    }
    if (featureName == FeatureName.sleepOnset) {
      return MLFeatureValue(double: Sleep_Onset)
    }
    if (featureName == FeatureName.headphoneAudioExposure) {
      return MLFeatureValue(double: Headphone_Audio_Exposure)
    }
    if (featureName == FeatureName.stepCount) {
      return MLFeatureValue(double: Step_Count)
    }
    return nil
  }
  
  convenience init(healthKitData: [HealthKitData: Double]?) {
    self.init(
      Mindful_Session: healthKitData?[HealthKitData.mindfulSession] ?? 0.0,
      Sleep_Seconds: healthKitData?[HealthKitData.sleepSeconds] ?? 0.0,
      Sleep_Onset: healthKitData?[HealthKitData.sleepOnset] ?? 0.0,
      Headphone_Audio_Exposure: healthKitData?[HealthKitData.headphoneAudioExposure] ?? 0.0,
      Step_Count: healthKitData?[HealthKitData.stepCount] ?? 0.0
    )
  }
  
  init(Mindful_Session: Double, Sleep_Seconds: Double, Sleep_Onset: Double, Headphone_Audio_Exposure: Double, Step_Count: Double) {
    self.Mindful_Session = Mindful_Session
    self.Sleep_Seconds = Sleep_Seconds
    self.Sleep_Onset = Sleep_Onset
    self.Headphone_Audio_Exposure = Headphone_Audio_Exposure
    self.Step_Count = Step_Count
  }
  
}
