//
//  AutonomicBaselineInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/17/26.
//

import CoreML
import Foundation

/// Personal-baseline-relative autonomic features: each metric standardized
/// against the user's own causal 14-day rolling baseline (its z-score), plus
/// the short-window slope of that z-score (see `BaselineFeatures`). A value of
/// 0 means "at baseline" / "no change", so a missing feature defaults to 0 —
/// semantically valid, unlike a raw metric's zero. All columns are gated by a
/// single `baselineRelative` preference.
class AutonomicBaselineInput: MLFeatureProvider {

  struct FeatureName {
    static let hrv = "HRV Baseline Z"
    static let restingHeartRate = "Resting Heart Rate Baseline Z"
    static let respiratoryRate = "Respiratory Rate Baseline Z"
    static let sleepSeconds = "Sleep Baseline Z"
    static let bodyTemperature = "Body Temperature Baseline Z"
    static let wristTemperature = "Wrist Temperature Baseline Z"
    static let basalBodyTemperature = "Basal Body Temperature Baseline Z"
    static let rmssd = "HRV RMSSD Baseline Z"
    static let pnn50 = "HRV pNN50 Baseline Z"
    static let lfhf = "HRV LF HF Baseline Z"

    static let hrvSlope = "HRV Baseline Slope"
    static let restingHeartRateSlope = "Resting Heart Rate Baseline Slope"
    static let respiratoryRateSlope = "Respiratory Rate Baseline Slope"
    static let sleepSecondsSlope = "Sleep Baseline Slope"
    static let bodyTemperatureSlope = "Body Temperature Baseline Slope"
    static let wristTemperatureSlope = "Wrist Temperature Baseline Slope"
    static let basalBodyTemperatureSlope = "Basal Body Temperature Baseline Slope"
    static let rmssdSlope = "HRV RMSSD Baseline Slope"
    static let pnn50Slope = "HRV pNN50 Baseline Slope"
    static let lfhfSlope = "HRV LF HF Baseline Slope"
  }

  /// The z-score column name for each baseline metric.
  static let zFeatureName: [HealthKitData: String] = [
    .heartRateVariabilitySDNN: FeatureName.hrv,
    .restingHeartRate: FeatureName.restingHeartRate,
    .respiratoryRate: FeatureName.respiratoryRate,
    .sleepSeconds: FeatureName.sleepSeconds,
    .bodyTemperature: FeatureName.bodyTemperature,
    .wristTemperature: FeatureName.wristTemperature,
    .basalBodyTemperature: FeatureName.basalBodyTemperature,
    .hrvRMSSD: FeatureName.rmssd,
    .hrvPNN50: FeatureName.pnn50,
    .hrvLFHF: FeatureName.lfhf
  ]

  /// The slope column name for each baseline metric.
  static let slopeFeatureName: [HealthKitData: String] = [
    .heartRateVariabilitySDNN: FeatureName.hrvSlope,
    .restingHeartRate: FeatureName.restingHeartRateSlope,
    .respiratoryRate: FeatureName.respiratoryRateSlope,
    .sleepSeconds: FeatureName.sleepSecondsSlope,
    .bodyTemperature: FeatureName.bodyTemperatureSlope,
    .wristTemperature: FeatureName.wristTemperatureSlope,
    .basalBodyTemperature: FeatureName.basalBodyTemperatureSlope,
    .hrvRMSSD: FeatureName.rmssdSlope,
    .hrvPNN50: FeatureName.pnn50Slope,
    .hrvLFHF: FeatureName.lfhfSlope
  ]

  let preferences = Preferences.Predictors()

  var HRV_Baseline_Z: Double
  var Resting_Heart_Rate_Baseline_Z: Double
  var Respiratory_Rate_Baseline_Z: Double
  var Sleep_Baseline_Z: Double
  var Body_Temperature_Baseline_Z: Double
  var Wrist_Temperature_Baseline_Z: Double
  var Basal_Body_Temperature_Baseline_Z: Double

  var RMSSD_Baseline_Z: Double
  var pNN50_Baseline_Z: Double
  var LFHF_Baseline_Z: Double

  var HRV_Baseline_Slope: Double
  var Resting_Heart_Rate_Baseline_Slope: Double
  var Respiratory_Rate_Baseline_Slope: Double
  var Sleep_Baseline_Slope: Double
  var Body_Temperature_Baseline_Slope: Double
  var Wrist_Temperature_Baseline_Slope: Double
  var Basal_Body_Temperature_Baseline_Slope: Double

  var RMSSD_Baseline_Slope: Double
  var pNN50_Baseline_Slope: Double
  var LFHF_Baseline_Slope: Double

  var featureNames: Set<String> {
    get {
      guard preferences.baselineRelative == true else {
        return Set<String>()
      }
      return Set(AutonomicBaselineInput.zFeatureName.values)
        .union(AutonomicBaselineInput.slopeFeatureName.values)
    }
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    switch featureName {
    case FeatureName.hrv: return MLFeatureValue(double: HRV_Baseline_Z)
    case FeatureName.restingHeartRate: return MLFeatureValue(double: Resting_Heart_Rate_Baseline_Z)
    case FeatureName.respiratoryRate: return MLFeatureValue(double: Respiratory_Rate_Baseline_Z)
    case FeatureName.sleepSeconds: return MLFeatureValue(double: Sleep_Baseline_Z)
    case FeatureName.bodyTemperature: return MLFeatureValue(double: Body_Temperature_Baseline_Z)
    case FeatureName.wristTemperature: return MLFeatureValue(double: Wrist_Temperature_Baseline_Z)
    case FeatureName.basalBodyTemperature: return MLFeatureValue(double: Basal_Body_Temperature_Baseline_Z)
    case FeatureName.rmssd: return MLFeatureValue(double: RMSSD_Baseline_Z)
    case FeatureName.pnn50: return MLFeatureValue(double: pNN50_Baseline_Z)
    case FeatureName.lfhf: return MLFeatureValue(double: LFHF_Baseline_Z)
    case FeatureName.hrvSlope: return MLFeatureValue(double: HRV_Baseline_Slope)
    case FeatureName.restingHeartRateSlope: return MLFeatureValue(double: Resting_Heart_Rate_Baseline_Slope)
    case FeatureName.respiratoryRateSlope: return MLFeatureValue(double: Respiratory_Rate_Baseline_Slope)
    case FeatureName.sleepSecondsSlope: return MLFeatureValue(double: Sleep_Baseline_Slope)
    case FeatureName.bodyTemperatureSlope: return MLFeatureValue(double: Body_Temperature_Baseline_Slope)
    case FeatureName.wristTemperatureSlope: return MLFeatureValue(double: Wrist_Temperature_Baseline_Slope)
    case FeatureName.basalBodyTemperatureSlope: return MLFeatureValue(double: Basal_Body_Temperature_Baseline_Slope)
    case FeatureName.rmssdSlope: return MLFeatureValue(double: RMSSD_Baseline_Slope)
    case FeatureName.pnn50Slope: return MLFeatureValue(double: pNN50_Baseline_Slope)
    case FeatureName.lfhfSlope: return MLFeatureValue(double: LFHF_Baseline_Slope)
    default: return nil
    }
  }

  convenience init(baselineZ: [HealthKitData: Double]?, baselineSlope: [HealthKitData: Double]?) {
    self.init(
      HRV_Baseline_Z: baselineZ?[HealthKitData.heartRateVariabilitySDNN] ?? 0.0,
      Resting_Heart_Rate_Baseline_Z: baselineZ?[HealthKitData.restingHeartRate] ?? 0.0,
      Respiratory_Rate_Baseline_Z: baselineZ?[HealthKitData.respiratoryRate] ?? 0.0,
      Sleep_Baseline_Z: baselineZ?[HealthKitData.sleepSeconds] ?? 0.0,
      Body_Temperature_Baseline_Z: baselineZ?[HealthKitData.bodyTemperature] ?? 0.0,
      Wrist_Temperature_Baseline_Z: baselineZ?[HealthKitData.wristTemperature] ?? 0.0,
      Basal_Body_Temperature_Baseline_Z: baselineZ?[HealthKitData.basalBodyTemperature] ?? 0.0,
      RMSSD_Baseline_Z: baselineZ?[HealthKitData.hrvRMSSD] ?? 0.0,
      pNN50_Baseline_Z: baselineZ?[HealthKitData.hrvPNN50] ?? 0.0,
      LFHF_Baseline_Z: baselineZ?[HealthKitData.hrvLFHF] ?? 0.0,
      HRV_Baseline_Slope: baselineSlope?[HealthKitData.heartRateVariabilitySDNN] ?? 0.0,
      Resting_Heart_Rate_Baseline_Slope: baselineSlope?[HealthKitData.restingHeartRate] ?? 0.0,
      Respiratory_Rate_Baseline_Slope: baselineSlope?[HealthKitData.respiratoryRate] ?? 0.0,
      Sleep_Baseline_Slope: baselineSlope?[HealthKitData.sleepSeconds] ?? 0.0,
      Body_Temperature_Baseline_Slope: baselineSlope?[HealthKitData.bodyTemperature] ?? 0.0,
      Wrist_Temperature_Baseline_Slope: baselineSlope?[HealthKitData.wristTemperature] ?? 0.0,
      Basal_Body_Temperature_Baseline_Slope: baselineSlope?[HealthKitData.basalBodyTemperature] ?? 0.0,
      RMSSD_Baseline_Slope: baselineSlope?[HealthKitData.hrvRMSSD] ?? 0.0,
      pNN50_Baseline_Slope: baselineSlope?[HealthKitData.hrvPNN50] ?? 0.0,
      LFHF_Baseline_Slope: baselineSlope?[HealthKitData.hrvLFHF] ?? 0.0
    )
  }

  init(HRV_Baseline_Z: Double, Resting_Heart_Rate_Baseline_Z: Double, Respiratory_Rate_Baseline_Z: Double, Sleep_Baseline_Z: Double, Body_Temperature_Baseline_Z: Double, Wrist_Temperature_Baseline_Z: Double, Basal_Body_Temperature_Baseline_Z: Double, RMSSD_Baseline_Z: Double, pNN50_Baseline_Z: Double, LFHF_Baseline_Z: Double, HRV_Baseline_Slope: Double, Resting_Heart_Rate_Baseline_Slope: Double, Respiratory_Rate_Baseline_Slope: Double, Sleep_Baseline_Slope: Double, Body_Temperature_Baseline_Slope: Double, Wrist_Temperature_Baseline_Slope: Double, Basal_Body_Temperature_Baseline_Slope: Double, RMSSD_Baseline_Slope: Double, pNN50_Baseline_Slope: Double, LFHF_Baseline_Slope: Double) {
    self.HRV_Baseline_Z = HRV_Baseline_Z
    self.Resting_Heart_Rate_Baseline_Z = Resting_Heart_Rate_Baseline_Z
    self.Respiratory_Rate_Baseline_Z = Respiratory_Rate_Baseline_Z
    self.Sleep_Baseline_Z = Sleep_Baseline_Z
    self.Body_Temperature_Baseline_Z = Body_Temperature_Baseline_Z
    self.Wrist_Temperature_Baseline_Z = Wrist_Temperature_Baseline_Z
    self.Basal_Body_Temperature_Baseline_Z = Basal_Body_Temperature_Baseline_Z
    self.RMSSD_Baseline_Z = RMSSD_Baseline_Z
    self.pNN50_Baseline_Z = pNN50_Baseline_Z
    self.LFHF_Baseline_Z = LFHF_Baseline_Z
    self.HRV_Baseline_Slope = HRV_Baseline_Slope
    self.Resting_Heart_Rate_Baseline_Slope = Resting_Heart_Rate_Baseline_Slope
    self.Respiratory_Rate_Baseline_Slope = Respiratory_Rate_Baseline_Slope
    self.Sleep_Baseline_Slope = Sleep_Baseline_Slope
    self.Body_Temperature_Baseline_Slope = Body_Temperature_Baseline_Slope
    self.Wrist_Temperature_Baseline_Slope = Wrist_Temperature_Baseline_Slope
    self.Basal_Body_Temperature_Baseline_Slope = Basal_Body_Temperature_Baseline_Slope
    self.RMSSD_Baseline_Slope = RMSSD_Baseline_Slope
    self.pNN50_Baseline_Slope = pNN50_Baseline_Slope
    self.LFHF_Baseline_Slope = LFHF_Baseline_Slope
  }

}
