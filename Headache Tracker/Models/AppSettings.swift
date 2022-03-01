//
//  AppSettings.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import ApplicationKey

class AppSettings {
  static let healthIntegration = ApplicationKey(from: "healthIntegration")
  static let checkInAlerts = ApplicationKey(from: "checkInAlerts")
  static let checkInInterval = ApplicationKey(from: "checkInInterval")
  static let realTimeAlerts = ApplicationKey(from: "realTimeAlerts")
  static let dailyOutlookAlerts = ApplicationKey(from: "dailyOutlookAlerts")
  static let dailyOutlookTime = ApplicationKey(from: "dailyOutlookTime")
  
  static let filterCount = ApplicationKey(from: "filterCount")
  static let filterUnit = ApplicationKey(from: "filterUnit")
  
  static let debugShowAllViews = ApplicationKey(from: "debugShowAllViews")
  static let debugLastOutlookDate = ApplicationKey(from: "debugLastOutlookDate")
  static let debugNextOutlookDate = ApplicationKey(from: "debugNextOutlookDate")
  static let debugLastTrainingDate = ApplicationKey(from: "debugLastTrainingDate")
  static let debugNextTrainingDate = ApplicationKey(from: "debugNextTrainingDate")
  static let debugLastPredictionDate = ApplicationKey(from: "debugLastPredictionDate")
  static let debugNextPredictionDate = ApplicationKey(from: "debugNextPredictionDate")
}
