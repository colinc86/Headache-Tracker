//
//  AppSettings.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import ApplicationKey

struct AppSettings {
  static let healthIntegration = ApplicationKey(from: "healthIntegration")
  static let checkInAlerts = ApplicationKey(from: "checkInAlerts")
  static let checkInInterval = ApplicationKey(from: "checkInInterval")
  static let realTimeAlerts = ApplicationKey(from: "realTimeAlerts")
  static let dailyOutlookAlerts = ApplicationKey(from: "dailyOutlookAlerts")
  static let dailyOutlookTime = ApplicationKey(from: "dailyOutlookTime")
}
