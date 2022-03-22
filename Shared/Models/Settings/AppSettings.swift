//
//  AppSettings.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import ApplicationKey

struct AppSettings {
  static let measurementSystem = ApplicationKey(from: "measurementSystem")
  
  static let enableCrashReporting = ApplicationKey(from: "enableCrashReporting")
  
  static let healthIntegration = ApplicationKey(from: "healthIntegration")
  static let checkInAlerts = ApplicationKey(from: "checkInAlerts")
  static let checkInInterval = ApplicationKey(from: "checkInInterval")
  static let realTimeAlerts = ApplicationKey(from: "realTimeAlerts")
  static let dailyOutlookAlerts = ApplicationKey(from: "dailyOutlookAlerts")
  static let dailyOutlookTime = ApplicationKey(from: "dailyOutlookTime")
  
  static let filterCount = ApplicationKey(from: "filterCount")
  static let filterUnit = ApplicationKey(from: "filterUnit")
  
  static let debugLastOutlookDate = ApplicationKey(from: "debugLastOutlookDate")
  static let debugNextOutlookDate = ApplicationKey(from: "debugNextOutlookDate")
  static let debugLastTrainingDate = ApplicationKey(from: "debugLastTrainingDate")
  static let debugNextTrainingDate = ApplicationKey(from: "debugNextTrainingDate")
  static let debugLastPredictionDate = ApplicationKey(from: "debugLastPredictionDate")
  static let debugNextPredictionDate = ApplicationKey(from: "debugNextPredictionDate")
  
  struct ListOptions {
    static let onset = ApplicationKey(from: "listoptions.onset")
    static let duration = ApplicationKey(from: "listoptions.duration")
    static let progression = ApplicationKey(from: "listoptions.progression")
    static let outlook = ApplicationKey(from: "listoptions.outlook")
    static let severity = ApplicationKey(from: "listoptions.severity")
  }
  
  struct Predictors {
    static let secondsSinceMidnight = ApplicationKey(from: "secondsSinceMidnight")
    static let weekday = ApplicationKey(from: "weekday")
    static let mindfulSession = ApplicationKey(from: "mindfulSession")
    static let sleepSeconds = ApplicationKey(from: "sleepSeconds")
    static let sleepOnset = ApplicationKey(from: "sleepOnset")
    static let headphoneAudioExposure = ApplicationKey(from: "headphoneAudioExposure")
    static let stepCount = ApplicationKey(from: "stepCount")
    static let barometricPressure = ApplicationKey(from: "barometricPressure")
    static let humidity = ApplicationKey(from: "humidity")
    static let temperature = ApplicationKey(from: "temperature")
    static let environmentalAudioExposure = ApplicationKey(from: "environmentalAudioExposure")
    static let heartRate = ApplicationKey(from: "heartRate")
    static let respiratoryRate = ApplicationKey(from: "respiratoryRate")
    static let oxygenSaturation = ApplicationKey(from: "oxygenSaturation")
    static let heartRateVariability = ApplicationKey(from: "heartRateVariability")
    static let walkingHeartRateAverage = ApplicationKey(from: "walkingHeartRateAverage")
    static let restingHeartRate = ApplicationKey(from: "restingHeartRate")
  }
}
