//
//  AppSettings.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Foundation
import ApplicationKey
import SwiftUI

class AppSettings {
  
  // MARK: Types
  
  /// Contains settings used in DEBUG builds.
  class DebugSettings: ObservableObject {
    struct Keys {
      static let lastOutlookDate    = ApplicationKey(from: "settings.debug.lastOutlookDate")
      static let nextOutlookDate    = ApplicationKey(from: "settings.debug.nextOutlookDate")
      static let lastTrainingDate   = ApplicationKey(from: "settings.debug.lastTrainingDate")
      static let nextTrainingDate   = ApplicationKey(from: "settings.debug.nextTrainingDate")
      static let lastPredictionDate = ApplicationKey(from: "settings.debug.lastPredictionDate")
      static let nextPredictionDate = ApplicationKey(from: "settings.debug.nextPredictionDate")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = DebugSettings()
    }
    
    /// The last date an outlook prediction was performed.
    @AppStorage(Keys.lastOutlookDate) var lastOutlookDate: Date?
    
    /// The next date an outlook prediction will be performed.
    @AppStorage(Keys.nextOutlookDate) var nextOutlookDate: Date?
    
    /// The last date the models were trained.
    @AppStorage(Keys.lastTrainingDate) var lastTrainingDate: Date?
    
    /// The next date the models will be trained.
    @AppStorage(Keys.nextTrainingDate) var nextTrainingDate: Date?
    
    /// The last date a prediction was performed.
    @AppStorage(Keys.lastPredictionDate) var lastPredictionDate: Date?
    
    /// The next date a prediction will be performed.
    @AppStorage(Keys.nextPredictionDate) var nextPredictionDate: Date?
  }
  
  /// General settings used throughout the app.
  class GeneralSettings: ObservableObject {
    struct Keys {
      static let measurementSystem    = ApplicationKey(from: "settings.general.measurementSystem")
      static let colorTheme           = ApplicationKey(from: "settings.general.colorTheme")
      static let shouldDimScreen      = ApplicationKey(from: "settings.general.shouldDimScreen")
      static let screenDimPercent     = ApplicationKey(from: "settings.general.screenDimPercent")
      static let enableCrashReporting = ApplicationKey(from: "settings.general.enableCrashReporting")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = GeneralSettings()
    }
    
    /// The application's custom color theme.
    @AppStorage(Keys.colorTheme) var colorTheme: ColorTheme = .system
    
    /// Whether or not the screen should dim.
    @AppStorage(Keys.shouldDimScreen) var shouldDimScreen: Bool = false
    
    /// The amount of screen dimming that should be applied if `shouldDimScreen`
    /// is set to `true`.
    @AppStorage(Keys.screenDimPercent) var screenDimPercent = 0.5
    
    /// The application's measurement system.
    @AppStorage(Keys.measurementSystem) var measurementSystem: MeasurementSystem = NSLocale.system.usesMetricSystem ? .metric : .imperial
    
    /// Whether or not to enable crash reporting with Crashlytics.
    @AppStorage(Keys.enableCrashReporting) var crashReportingEnabled = true
  }
  
  /// Settings to use when creating and editing headaches.
  class HeadacheSettings: ObservableObject {
    struct Keys {
      static let defaultHeadacheType           = ApplicationKey(from: "settings.headaches.defaultHeadacheType")
      static let defaultHeadacheClassification = ApplicationKey(from: "settings.headaches.defaultHeadacheClassification")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = HeadacheSettings()
    }
    
    /// The default headache type to use when creating a new headache.
    @AppStorage(Keys.defaultHeadacheType) var defaultHeadacheType = Headache.Types.cluster
    
    /// The default headache classification to use when creating a new headache.
    @AppStorage(Keys.defaultHeadacheClassification) var defaultHeadacheClassification = Headache.Classification.primary
  }
  
  /// Health data and app integration settings.
  class HealthSettings: ObservableObject {
    struct Keys {
      static let enabled           = ApplicationKey(from: "settings.health.enabled")
      static let deleteDisposition = ApplicationKey(from: "settings.health.deletedisposition")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = HealthSettings()
    }
    
    /// Whether or not Health app integration has been enabled.
    @AppStorage(Keys.enabled) var enabled = false
    
    /// How the manager should handle health kit data when deleting a headache.
    @AppStorage(Keys.deleteDisposition) var deleteDisposition: HeadacheManager.DeleteDisposition = .ask
  }
  
  /// Settings for viewing lists and managing component visibility.
  class ListSettings: ObservableObject {
    struct Keys {
      static let type        = ApplicationKey(from: "settings.listoptions.type")
      static let onset       = ApplicationKey(from: "settings.listoptions.onset")
      static let duration    = ApplicationKey(from: "settings.listoptions.duration")
      static let progression = ApplicationKey(from: "settings.listoptions.progression")
      static let notes       = ApplicationKey(from: "settings.listoptions.notes")
      static let tags        = ApplicationKey(from: "settings.listoptions.tags")
      static let outlook     = ApplicationKey(from: "settings.listoptions.outlook")
      static let severity    = ApplicationKey(from: "settings.listoptions.severity")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = ListSettings()
    }
    
    /// Whether the type view should be shown.
    @AppStorage(Keys.type) var showTypeView = true
    
    /// Whether the onset view should be shown.
    @AppStorage(Keys.onset) var showOnsetView = true
    
    /// Whether the duration view should be shown.
    @AppStorage(Keys.duration) var showDurationView = true
    
    /// Whether the progression view should be shown.
    @AppStorage(Keys.progression) var showProgressionView = true
    
    /// Whether the notes view should be shown.
    @AppStorage(Keys.notes) var showNotesView = true
    
    /// Whether the tags view should be shown.
    @AppStorage(Keys.tags) var showTagsView = true
    
    /// Whether the outlook view should be shown.
    @AppStorage(Keys.outlook) var showOutlookView = true
    
    /// Whether the severity view should be shown.
    @AppStorage(Keys.severity) var showSeverityView = true
  }
  
  /// User notification settings.
  class NotificationSettings: ObservableObject {
    struct Keys {
      static let checkInAlerts      = ApplicationKey(from: "settings.notifications.checkInAlerts")
      static let checkInInterval    = ApplicationKey(from: "settings.notifications.checkInInterval")
      static let realTimeAlerts     = ApplicationKey(from: "settings.notifications.realTimeAlerts")
      static let dailyOutlookAlerts = ApplicationKey(from: "settings.notifications.dailyOutlookAlerts")
      static let dailyOutlookTime   = ApplicationKey(from: "settings.notifications.dailyOutlookTime")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = NotificationSettings()
    }
    
    /// Whether check-in alerts should be displayed to the user after
    /// `checkInInterval` has elapsed.
    @AppStorage(Keys.checkInAlerts) var checkInAlerts = false
    
    /// The check-in interval setting to use when `checkInAlerts` is true.
    @AppStorage(Keys.checkInInterval) var checkInInterval = TimeInterval(3600.0)
    
    /// Whether real-time alerts should be shown to the user.
    @AppStorage(Keys.realTimeAlerts) var realTimeAlerts = false
    
    /// Whether daily-outlook alerts should take place and be shown to the user.
    @AppStorage(Keys.dailyOutlookAlerts) var dailyOutlookAlerts = false
    
    /// The time interval after midnight at which a daily outlook alert should
    /// take place.
    @AppStorage(Keys.dailyOutlookTime) var dailyOutlookTime = TimeInterval(28800.0)
  }
  
  /// Filter settings to be used on the analyze content view.
  class FilterSettings: ObservableObject {
    struct Keys {
      static let count = ApplicationKey(from: "settings.filter.count")
      static let unit  = ApplicationKey(from: "settings.filter.unit")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = FilterSettings()
    }
    
    /// The health integration setting.
    @AppStorage(Keys.count) var count: Int = 1
    
    /// The health integration setting.
    @AppStorage(Keys.unit) var unit: FilterUnit = .month
  }
  
  /// The settings used for predictors.
  class PredictionSettings: ObservableObject {
    struct Keys {
      static let secondsSinceMidnight       = ApplicationKey(from: "settings.predictors.secondsSinceMidnight")
      static let weekday                    = ApplicationKey(from: "settings.predictors.weekday")
      static let mindfulSession             = ApplicationKey(from: "settings.predictors.mindfulSession")
      static let sleepSeconds               = ApplicationKey(from: "settings.predictors.sleepSeconds")
      static let sleepOnset                 = ApplicationKey(from: "settings.predictors.sleepOnset")
      static let headphoneAudioExposure     = ApplicationKey(from: "settings.predictors.headphoneAudioExposure")
      static let stepCount                  = ApplicationKey(from: "settings.predictors.stepCount")
      static let barometricPressure         = ApplicationKey(from: "settings.predictors.barometricPressure")
      static let humidity                   = ApplicationKey(from: "settings.predictors.humidity")
      static let temperature                = ApplicationKey(from: "settings.predictors.temperature")
      static let environmentalAudioExposure = ApplicationKey(from: "settings.predictors.environmentalAudioExposure")
      static let heartRate                  = ApplicationKey(from: "settings.predictors.heartRate")
      static let respiratoryRate            = ApplicationKey(from: "settings.predictors.respiratoryRate")
      static let oxygenSaturation           = ApplicationKey(from: "settings.predictors.oxygenSaturation")
      static let heartRateVariability       = ApplicationKey(from: "settings.predictors.heartRateVariability")
      static let walkingHeartRateAverage    = ApplicationKey(from: "settings.predictors.walkingHeartRateAverage")
      static let restingHeartRate           = ApplicationKey(from: "settings.predictors.restingHeartRate")
    }
    
    /// An environment key to set settings.
    struct EnvKey: EnvironmentKey {
      static var defaultValue = PredictionSettings()
    }
    
    /// Whether the model should include this key.
    @AppStorage(Keys.secondsSinceMidnight) var secondsSinceMidnight = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.weekday) var weekday = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.mindfulSession) var mindfulSession = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.sleepSeconds) var sleepSeconds = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.sleepOnset) var sleepOnset = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.headphoneAudioExposure) var headphoneAudioExposure = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.stepCount) var stepCount = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.barometricPressure) var barometricPressure = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.humidity) var humidity = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.temperature) var temperature = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.environmentalAudioExposure) var environmentalAudioExposure = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.heartRate) var heartRate = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.respiratoryRate) var respiratoryRate = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.oxygenSaturation) var oxygenSaturation = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.heartRateVariability) var heartRateVariability = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.walkingHeartRateAverage) var walkingHeartRateAverage = true
    
    /// Whether the model should include this key.
    @AppStorage(Keys.restingHeartRate) var restingHeartRate = true
    
    /// Gets the current settings dictionary.
    func settingsDictionary() -> [String: Bool] {
      return [
        Keys.secondsSinceMidnight: secondsSinceMidnight,
        Keys.weekday: weekday,
        Keys.mindfulSession: mindfulSession,
        Keys.sleepSeconds: sleepSeconds,
        Keys.sleepOnset: sleepOnset,
        Keys.headphoneAudioExposure: headphoneAudioExposure,
        Keys.stepCount: stepCount,
        Keys.barometricPressure: barometricPressure,
        Keys.humidity: humidity,
        Keys.temperature: temperature,
        Keys.environmentalAudioExposure: environmentalAudioExposure,
        Keys.heartRate: heartRate,
        Keys.respiratoryRate: respiratoryRate,
        Keys.oxygenSaturation: oxygenSaturation,
        Keys.heartRateVariability: heartRateVariability,
        Keys.walkingHeartRateAverage: walkingHeartRateAverage,
        Keys.restingHeartRate: restingHeartRate
      ]
    }
  }
  
  // MARK: Static properties
  
  /// The shared app settings.
  static let shared = AppSettings()
  
  // MARK: Properties
  
  @ObservedObject var debug = DebugSettings()
  @ObservedObject var general = GeneralSettings()
  @ObservedObject var headaches = HeadacheSettings()
  @ObservedObject var health = HealthSettings()
  @ObservedObject var lists = ListSettings()
  @ObservedObject var notifications = NotificationSettings()
  @ObservedObject var filters = FilterSettings()
  @ObservedObject var predictions = PredictionSettings()
  
}
