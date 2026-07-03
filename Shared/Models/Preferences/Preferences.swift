//
//  Preferences.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import Combine
import SwiftUI
import WidgetKit

struct Preferences {
  
  // MARK: Types
  
  /// A key.
  typealias Key = String
  
  // MARK: Static properties
  
  /// The notification to signify that the prediction value changed.
  static let predictionDidChangeNotification = Notification.Name(rawValue: "predictionDidChangeNotification")
  
  // MARK: Static methods
  
  /// Adds a prediction observer.
  ///
  /// - Parameter block: The block to execute.
  /// - Returns: An observer.
  static func addPredictionObserver(using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: predictionDidChangeNotification, object: nil, queue: nil, using: block)
  }
  
  /// Removes a prediction observer.
  ///
  /// - Parameter observer: The observer to remove.
  static func removePredictionObserver(_ observer: Any) {
    NotificationCenter.default.removeObserver(observer, name: predictionDidChangeNotification, object: nil)
  }
  
  // MARK: - Public properties
  
  var debug = Debug()
  var filters = Filters()
  var general = General()
  var headaches = Headaches()
  var health = Health()
  var lists = Lists()
  var notifications = Notifications()
  var predictors = Predictors()
  var shared = Shared()

  /// The sync preferences.
  var sync = Sync()
  
  // MARK: - Types
  
  /// Debug settings.
  struct Debug {
    struct Keys {
      static let lastOutlookDate    = Key("settings.debug.lastOutlookDate")
      static let nextOutlookDate    = Key("settings.debug.nextOutlookDate")
      static let lastTrainingDate   = Key("settings.debug.lastTrainingDate")
      static let nextTrainingDate   = Key("settings.debug.nextTrainingDate")
      static let lastPredictionDate = Key("settings.debug.lastPredictionDate")
      static let nextPredictionDate = Key("settings.debug.nextPredictionDate")
      static let lastRiskAlertDate  = Key("settings.debug.lastRiskAlertDate")
    }
    
    struct Defaults {
      static let lastOutlookDate: Date? = nil
      static let nextOutlookDate: Date? = nil
      static let lastTrainingDate: Date? = nil
      static let nextTrainingDate: Date? = nil
      static let lastPredictionDate: Date? = nil
      static let nextPredictionDate: Date? = nil
      static let lastRiskAlertDate: Date? = nil
    }
    
    /// The last date an outlook prediction was performed.
    @UserDefault(Keys.lastOutlookDate) var lastOutlookDate: Date? = Defaults.lastOutlookDate
    
    /// The next date an outlook prediction will be performed.
    @UserDefault(Keys.nextOutlookDate) var nextOutlookDate: Date? = Defaults.nextOutlookDate

    /// The last date the models were trained.
    @UserDefault(Keys.lastTrainingDate) var lastTrainingDate: Date? = Defaults.lastTrainingDate

    /// The next date the models will be trained.
    @UserDefault(Keys.nextTrainingDate) var nextTrainingDate: Date? = Defaults.nextTrainingDate

    /// The last date a prediction was performed.
    @UserDefault(Keys.lastPredictionDate) var lastPredictionDate: Date? = Defaults.lastPredictionDate

    /// The next date a prediction will be performed.
    @UserDefault(Keys.nextPredictionDate) var nextPredictionDate: Date? = Defaults.nextPredictionDate

    /// The last date a high-risk alert was presented.
    @UserDefault(Keys.lastRiskAlertDate) var lastRiskAlertDate: Date? = Defaults.lastRiskAlertDate
  }
  
  /// Filter settings.
  struct Filters {
    struct Keys {
      static let count = Key("settings.filter.count")
      static let unit  = Key("settings.filter.unit")
    }
    
    struct Defaults {
      static let count = 1
      static let unit = FilterUnit.month
    }
    
    /// The health integration setting.
    @UserDefault(Keys.count) var count = Defaults.count
    
    /// The health integration setting.
    @RawUserDefault(Keys.unit) var unit = Defaults.unit
  }

  /// General settings.
  struct General {
    struct Keys {
      static let measurementSystem     = Key("settings.general.measurementSystem")
      static let colorTheme            = Key("settings.general.colorTheme")
      static let shouldDimScreen       = Key("settings.general.shouldDimScreen")
      static let screenDimPercent      = Key("settings.general.screenDimPercent")
      static let crashReportingEnabled = Key("settings.general.enableCrashReporting")
    }
    
    struct Defaults {
      static let measurementSystem: MeasurementSystem = Locale.current.measurementSystem == .metric ? .metric : .imperial
      static let colorTheme = ColorTheme.system
      static let shouldDimScreen = false
      static let screenDimPercent = 0.5
      static let crashReportingEnabled = true
    }

    /// The application's custom color theme.
    @RawUserDefault(Keys.colorTheme, store: .shared) var colorTheme = Defaults.colorTheme

    /// Whether or not the screen should dim.
    @UserDefault(Keys.shouldDimScreen) var shouldDimScreen = Defaults.shouldDimScreen

    /// The amount of screen dimming that should be applied if `shouldDimScreen`
    /// is set to `true`.
    @UserDefault(Keys.screenDimPercent) var screenDimPercent = Defaults.screenDimPercent

    /// The application's measurement system.
    @RawUserDefault(Keys.measurementSystem, store: .shared) var measurementSystem = Defaults.measurementSystem

    /// Whether or not to enable crash reporting with Crashlytics.
    @UserDefault(Keys.crashReportingEnabled) var crashReportingEnabled = Defaults.crashReportingEnabled
  }

  /// Headache settings.
  struct Headaches {
    struct Keys {
      static let defaultHeadacheType           = Key("settings.headaches.defaultHeadacheType")
      static let defaultHeadacheClassification = Key("settings.headaches.defaultHeadacheClassification")
    }
    
    struct Defaults {
      static let defaultHeadacheType = Headache.Types.cluster
      static let defaultHeadacheClassification = Headache.Classification.primary
    }

    /// The default headache type to use when creating a new headache.
    @RawUserDefault(Keys.defaultHeadacheType) var defaultHeadacheType = Defaults.defaultHeadacheType

    /// The default headache classification to use when creating a new headache.
    @RawUserDefault(Keys.defaultHeadacheClassification) var defaultHeadacheClassification = Defaults.defaultHeadacheClassification
  }

  /// Health settings.
  struct Health {
    struct Keys {
      static let enabled           = Key("settings.health.enabled")
      static let deleteDisposition = Key("settings.health.deletedisposition")
    }
    
    struct Defaults {
      static let enabled = false
      static let deleteDisposition = HeadacheManager.DeleteDisposition.ask
    }

    /// Whether or not Health app integration has been enabled.
    @UserDefault(Keys.enabled) var enabled = Defaults.enabled

    /// How the manager should handle health kit data when deleting a headache.
    @RawUserDefault(Keys.deleteDisposition) var deleteDisposition = Defaults.deleteDisposition
  }

  /// List settings.
  struct Lists {
    struct Keys {
      static let expandedProgression = Key("settings.listoptions.expandedProgression")
      static let type                = Key("settings.listoptions.type")
      static let onset               = Key("settings.listoptions.onset")
      static let duration            = Key("settings.listoptions.duration")
      static let progression         = Key("settings.listoptions.progression")
      static let notes               = Key("settings.listoptions.notes")
      static let tags                = Key("settings.listoptions.tags")
      static let outlook             = Key("settings.listoptions.outlook")
      static let severity            = Key("settings.listoptions.severity")
      static let medications         = Key("settings.listoptions.medications")
      static let checkIn             = Key("settings.listoptions.checkIn")
      static let brief               = Key("settings.listoptions.brief")
    }
    
    struct Defaults {
      static let expanded = false
      static let shown = true
    }
    
    /// Whether the progression view should be drawn expanded.
    @UserDefault(Keys.expandedProgression) var expandedProgressionView = Defaults.expanded

    /// Whether the type view should be shown.
    @UserDefault(Keys.type) var showTypeView = Defaults.shown

    /// Whether the onset view should be shown.
    @UserDefault(Keys.onset) var showOnsetView = Defaults.shown

    /// Whether the duration view should be shown.
    @UserDefault(Keys.duration) var showDurationView = Defaults.shown

    /// Whether the progression view should be shown.
    @UserDefault(Keys.progression) var showProgressionView = Defaults.shown

    /// Whether the notes view should be shown.
    @UserDefault(Keys.notes) var showNotesView = Defaults.shown

    /// Whether the tags view should be shown.
    @UserDefault(Keys.tags) var showTagsView = Defaults.shown

    /// Whether the outlook view should be shown.
    @UserDefault(Keys.outlook) var showOutlookView = Defaults.shown

    /// Whether the severity view should be shown.
    @UserDefault(Keys.severity) var showSeverityView = Defaults.shown

    /// Whether the medications view should be shown.
    @UserDefault(Keys.medications) var showMedicationsView = Defaults.shown

    /// Whether the daily check-in view should be shown.
    @UserDefault(Keys.checkIn) var showCheckInView = Defaults.shown

    /// Whether the morning brief reasons should be shown.
    @UserDefault(Keys.brief) var showBriefView = Defaults.shown
  }

  /// Notification settings.
  struct Notifications {
    struct Keys {
      static let checkInAlerts      = Key("settings.notifications.checkInAlerts")
      static let checkInInterval    = Key("settings.notifications.checkInInterval")
      static let realTimeAlerts     = Key("settings.notifications.realTimeAlerts")
      static let dailyOutlookAlerts = Key("settings.notifications.dailyOutlookAlerts")
      static let dailyOutlookTime   = Key("settings.notifications.dailyOutlookTime")
      static let checkInReminderAlerts = Key("settings.notifications.checkInReminderAlerts")
      static let checkInReminderTime   = Key("settings.notifications.checkInReminderTime")
    }
    
    struct Defaults {
      static let checkInAlerts = false
      static let checkInInterval: TimeInterval = 3600.0
      static let realTimeAlerts = false
      static let dailyOutlookAlerts = false
      static let dailyOutlookTime: TimeInterval = 28800.0
      static let checkInReminderAlerts = false
      static let checkInReminderTime: TimeInterval = 72000.0
    }

    /// Whether check-in alerts should be displayed to the user after
    /// `checkInInterval` has elapsed.
    @UserDefault(Keys.checkInAlerts) var checkInAlerts = Defaults.checkInAlerts

    /// The check-in interval setting to use when `checkInAlerts` is true.
    @UserDefault(Keys.checkInInterval) var checkInInterval = Defaults.checkInInterval

    /// Whether real-time alerts should be shown to the user.
    @UserDefault(Keys.realTimeAlerts) var realTimeAlerts = Defaults.realTimeAlerts

    /// Whether daily-outlook alerts should take place and be shown to the user.
    @UserDefault(Keys.dailyOutlookAlerts) var dailyOutlookAlerts = Defaults.dailyOutlookAlerts

    /// The time interval after midnight at which a daily outlook alert should
    /// take place.
    @UserDefault(Keys.dailyOutlookTime) var dailyOutlookTime = Defaults.dailyOutlookTime

    /// Whether an evening reminder to log the daily check-in is scheduled.
    @UserDefault(Keys.checkInReminderAlerts) var checkInReminderAlerts = Defaults.checkInReminderAlerts

    /// The time interval after midnight at which the check-in reminder fires.
    @UserDefault(Keys.checkInReminderTime) var checkInReminderTime = Defaults.checkInReminderTime
  }

  /// Prediction settings.
  struct Predictors {
    struct Keys {
      static let secondsSinceMidnight       = Key("settings.predictors.secondsSinceMidnight")
      static let weekday                    = Key("settings.predictors.weekday")
      static let mindfulSession             = Key("settings.predictors.mindfulSession")
      static let sleepSeconds               = Key("settings.predictors.sleepSeconds")
      static let sleepOnset                 = Key("settings.predictors.sleepOnset")
      static let headphoneAudioExposure     = Key("settings.predictors.headphoneAudioExposure")
      static let stepCount                  = Key("settings.predictors.stepCount")
      static let barometricPressure         = Key("settings.predictors.barometricPressure")
      static let humidity                   = Key("settings.predictors.humidity")
      static let temperature                = Key("settings.predictors.temperature")
      static let environmentalAudioExposure = Key("settings.predictors.environmentalAudioExposure")
      static let heartRate                  = Key("settings.predictors.heartRate")
      static let respiratoryRate            = Key("settings.predictors.respiratoryRate")
      static let oxygenSaturation           = Key("settings.predictors.oxygenSaturation")
      static let heartRateVariability       = Key("settings.predictors.heartRateVariability")
      static let walkingHeartRateAverage    = Key("settings.predictors.walkingHeartRateAverage")
      static let restingHeartRate           = Key("settings.predictors.restingHeartRate")
      static let dietaryCaffeine            = Key("settings.predictors.dietaryCaffeine")
      static let dietaryWater               = Key("settings.predictors.dietaryWater")
      static let timeInDaylight             = Key("settings.predictors.timeInDaylight")
      static let exerciseMinutes            = Key("settings.predictors.exerciseMinutes")
      static let menstrualCycle             = Key("settings.predictors.menstrualCycle")
    }
    
    struct Defaults {
      static let enabled = true

      /// Sensitive types are opt-in; turning the toggle on triggers the
      /// deferred HealthKit authorization prompt.
      static let optIn = false
    }

    /// Whether the model should include this key.
    @UserDefault(Keys.secondsSinceMidnight) var secondsSinceMidnight = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.weekday) var weekday = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.mindfulSession) var mindfulSession = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.sleepSeconds) var sleepSeconds = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.sleepOnset) var sleepOnset = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.headphoneAudioExposure) var headphoneAudioExposure = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.stepCount) var stepCount = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.barometricPressure) var barometricPressure = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.humidity) var humidity = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.temperature) var temperature = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.environmentalAudioExposure) var environmentalAudioExposure = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.heartRate) var heartRate = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.respiratoryRate) var respiratoryRate = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.oxygenSaturation) var oxygenSaturation = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.heartRateVariability) var heartRateVariability = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.walkingHeartRateAverage) var walkingHeartRateAverage = Defaults.enabled

    /// Whether the model should include this key.
    @UserDefault(Keys.restingHeartRate) var restingHeartRate = Defaults.enabled

    /// Whether caffeine intake should be collected and correlated.
    @UserDefault(Keys.dietaryCaffeine) var dietaryCaffeine = Defaults.enabled

    /// Whether water intake should be collected and correlated.
    @UserDefault(Keys.dietaryWater) var dietaryWater = Defaults.enabled

    /// Whether time in daylight should be collected and correlated.
    @UserDefault(Keys.timeInDaylight) var timeInDaylight = Defaults.enabled

    /// Whether exercise minutes should be collected and correlated.
    @UserDefault(Keys.exerciseMinutes) var exerciseMinutes = Defaults.enabled

    /// Whether menstrual cycle data should be collected and correlated.
    @UserDefault(Keys.menstrualCycle) var menstrualCycle = Defaults.optIn

    /// Whether the given metric should be collected at all. The five
    /// correlation-only signals are gated at collection time; ML features
    /// are gated at feature-construction time instead.
    func isCollectionEnabled(_ data: HealthKitData) -> Bool {
      switch data {
      case .dietaryCaffeine: return dietaryCaffeine
      case .dietaryWater: return dietaryWater
      case .timeInDaylight: return timeInDaylight
      case .appleExerciseTime: return exerciseMinutes
      case .menstrualDaysSinceCycleStart, .menstrualFlowActive: return menstrualCycle
      default: return true
      }
    }

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
        Keys.restingHeartRate: restingHeartRate,
        Keys.dietaryCaffeine: dietaryCaffeine,
        Keys.dietaryWater: dietaryWater,
        Keys.timeInDaylight: timeInDaylight,
        Keys.exerciseMinutes: exerciseMinutes,
        Keys.menstrualCycle: menstrualCycle
      ]
    }
  }

  /// iCloud sync settings.
  struct Sync {
    struct Keys {
      static let enabled            = Key("settings.sync.enabled")
      static let didMigrateUserData = Key("settings.sync.didMigrateUserData")
      static let storeIsSplit       = Key("settings.sync.storeIsSplit")
    }

    struct Defaults {
      static let enabled = false
      static let didMigrateUserData = false
      static let storeIsSplit = false
    }

    /// Whether iCloud sync is enabled. Read at store setup, so changes take
    /// effect on the next launch. Lives in the shared suite because the
    /// widget's store must match the app's. One-way in practice: enabling
    /// turns on persistent history tracking, which can't be turned off.
    @UserDefault(Keys.enabled, store: .shared) var enabled = Defaults.enabled

    /// Whether the one-time user-data migration into the cloud store ran.
    @UserDefault(Keys.didMigrateUserData, store: .shared) var didMigrateUserData = Defaults.didMigrateUserData

    /// Whether the store has ever been split into Cloud/Local files. Set
    /// when sync is first enabled and never unset: turning sync off stops
    /// CloudKit mirroring but must keep the split layout (and history
    /// tracking), or every row in the cloud store would become unreachable.
    @UserDefault(Keys.storeIsSplit, store: .shared) var storeIsSplit = Defaults.storeIsSplit
  }

  /// Shared settings.
  struct Shared {
    struct Keys {
      static let currentRisk = Key("settings.shared.currentRisk")
      static let legacyCurrentPrediction = Key("settings.shared.currentPrediction")
      static let currentSeverity =   Key("settings.shared.currentSeverity")
      static let measurementSystem = Key("settings.shared.measurementSystem")
      static let customTypes =       Key("settings.shared.customTypes")
    }
    
    struct Defaults {
      static let currentRisk: RiskPrediction? = nil
      static let currentSeverity: Headache.Severity? = nil
      static let customTypes: [Headache.Types] = []
    }

    /// The current prediction.
    @CodableUserDefault(Keys.currentRisk, store: .shared) var currentRisk: RiskPrediction? = Defaults.currentRisk

    /// The current severity.
    var currentSeverity: Headache.Severity? {
      get {
        UserDefaults.shared?.rawValue(forKey: Keys.currentSeverity)
      }
      
      set {
        UserDefaults.shared?.setRawValue(newValue, forKey: Keys.currentSeverity)
      }
    }

    /// The application's custom headache types.
    @CodableUserDefault(Keys.customTypes, store: .shared) var customTypes: [Headache.Types] = Defaults.customTypes

    /// Sets the risk prediction and requests a widget reload.
    ///
    /// - Parameters:
    ///   - risk: The risk prediction.
    ///   - inWidget: Whether the method is being called from a widget.
    mutating func setCurrentRisk(_ risk: RiskPrediction, inWidget: Bool) {
      currentRisk = risk

      if inWidget {
        NotificationCenter.default.post(name: Preferences.predictionDidChangeNotification, object: nil)
      }
      else {
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.outlookWidgetKind)
      }
    }

    /// Sets the current severity and requests a widget reload.
    ///
    /// - Parameter severity: The current severity.
    mutating func setCurrentSeverity(_ severity: Headache.Severity?) {
      currentSeverity = severity
      WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.severityWidgetKind)

      if severity == nil {
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.outlookWidgetKind)
      }
    }
  }
}
