//
//  SettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import BugfenderSDK
import FirebaseCrashlytics
import SwiftUI

/// Displays the application's settings.
struct SettingsView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The health kit manager.
  @EnvironmentObject private var healthKitManager: HealthKitManager
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The app's data refresher.
  @EnvironmentObject private var refresher: Refresher
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) var colorScheme: AppColorScheme = .multicolor
  
  /// The application's dim screen setting.
  @AppStorage(AppSettings.shouldDimScreen) var shouldDimScreen: Bool = false
  
  /// The amount of screen dimming.
  @AppStorage(AppSettings.screenDimPercent) var screenDimPercent = 0.5
  
  /// The application's measurement system.
  @AppStorage(AppSettings.measurementSystem) var measurementSystem: MeasurementSystem = NSLocale.system.usesMetricSystem ? .metric : .imperial
  
  /// Whether or not to enable crash reporting.
  @AppStorage(AppSettings.enableCrashReporting) var enableCrashReporting = true
  
  /// The health integration setting.
  @AppStorage(AppSettings.Health.healthIntegration) private var healthIntegration = false
  
  /// How the manager should handle health kit data.
  @AppStorage(AppSettings.Health.deleteDisposition) private var deleteDisposition: HeadacheManager.DeleteDisposition = .ask
  
  /// The check-in alert setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The check-in interval setting to use when `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) private var dailyOutlookAlerts = false
  
  /// The daily outlook alert time.
  @AppStorage(AppSettings.dailyOutlookTime) private var dailyOutlookTime = TimeInterval(28800.0)
  
  /// The default headache type.
  @AppStorage(AppSettings.defaultHeadacheType) private var defaultHeadacheType = Headache.Types.cluster
  
  /// The default headache classification.
  @AppStorage(AppSettings.defaultHeadacheClassification) private var defaultHeadacheClassification = Headache.Classification.primary
  
  /// Whether we are showing the bug report content view.
  @State private var showingReportBug = false
  
  /// Whether we are showing the share feedback view.
  @State private var showingShareFeedback = false
  
  /// The headaches fetch request.
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  @AppStorage(AppSettings.Predictors.secondsSinceMidnight) var predictorSecondsSinceMidnight = true
  @AppStorage(AppSettings.Predictors.weekday) var predictorWeekday = true
  @AppStorage(AppSettings.Predictors.mindfulSession) var predictorMindfulSession = true
  @AppStorage(AppSettings.Predictors.sleepSeconds) var predictorSleepSeconds = true
  @AppStorage(AppSettings.Predictors.sleepOnset) var predictorSleepOnset = true
  @AppStorage(AppSettings.Predictors.headphoneAudioExposure) var predictorHeadphoneAudioExposure = true
  @AppStorage(AppSettings.Predictors.stepCount) var predictorStepCount = true
  @AppStorage(AppSettings.Predictors.barometricPressure) var predictorBarometricPressure = true
  @AppStorage(AppSettings.Predictors.humidity) var predictorHumidity = true
  @AppStorage(AppSettings.Predictors.temperature) var predictorTemperature = true
  @AppStorage(AppSettings.Predictors.environmentalAudioExposure) var predictorEnvironmentalAudioExposure = true
  @AppStorage(AppSettings.Predictors.heartRate) var predictorHeartRate = true
  @AppStorage(AppSettings.Predictors.respiratoryRate) var predictorRespiratoryRate = true
  @AppStorage(AppSettings.Predictors.oxygenSaturation) var predictorOxygenSaturation = true
  @AppStorage(AppSettings.Predictors.heartRateVariability) var predictorHeartRateVariability = true
  @AppStorage(AppSettings.Predictors.walkingHeartRateAverage) var predictorWalkingHeartRateAverage = true
  @AppStorage(AppSettings.Predictors.restingHeartRate) var predictorRestingHeartRate = true
  
  // MARK: Computed properties
    
  /// The health app integration binding.
  /// Will authorize health kit if set to true.
  private var healthAppIntegration: Binding<Bool> {
    Binding<Bool> {
      return !healthKitManager.needsAuthorization() && healthIntegration
    } set: { newValue in
      healthIntegration = newValue
      if healthIntegration {
        Task {
          do {
            try await healthKitManager.authorize()
          }
          catch {
            logError("Error authorizing HealthKit: \(error)")
          }
        }
      }
    }
  }
  
  /// The binding to modify the daily outlook time.
  private var dailyOutlookDate: Binding<Date> {
    Binding<Date> {
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(dailyOutlookTime)
    } set: { newValue in
      dailyOutlookTime = Calendar.current.timeIntervalSinceMidnight(newValue)
    }
  }
  
  /// Whether or not alerts are authorized.
  private var alertsDenied: Bool {
    return alertManager.authorizationStatus == .notDetermined || alertManager.authorizationStatus == .denied
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      Form {
        // Integrations
        Section("Integrations") {
          Toggle("Health App Integration", isOn: healthAppIntegration)
            .tint(colorScheme.themeColor(for: .brandColor))
          
          Picker("Delete Health Data", selection: $deleteDisposition) {
            ForEach(HeadacheManager.DeleteDisposition.allCases) { disposition in
              Text(disposition.rawValue.capitalized).tag(disposition)
            }
          }
        }
        
        // Headaches
        Section("Headaches") {
          Picker("Default Class", selection: $defaultHeadacheClassification) {
            Text(Headache.Classification.primary.title).tag(Headache.Classification.primary)
            Text(Headache.Classification.secondary.title).tag(Headache.Classification.secondary)
          }
          
          Picker("Default Type", selection: $defaultHeadacheType) {
            ForEach(Headache.Types.definedCases) { type in
              Text(type.title).tag(type)
            }
            ForEach(SharedUserDefaults.standard.customTypes) { type in
              Text(type.title).tag(type)
            }
          }
          
          Toggle("Check-Ins", isOn: $checkInAlerts)
            .tint(colorScheme.themeColor(for: .brandColor))
            .disabled(alertsDenied)
          
          Picker("Check-In Interval", selection: $checkInInterval) {
            ForEach(1 ..< 25) { i in
              Text("\(i) Hour\(i > 1 ? "s" : "")").tag(TimeInterval(i) * 3600.0)
            }
          }
          .disabled(!checkInAlerts)
          .disabled(alertsDenied)
        }
        
        // Predictions
        Section("Predictions") {
          NavigationLink {
            PredictorsView()
          } label: {
            SubtitleCell(title: "My Predictors", subtitle: "\(settingsDictionary().reduce(0, { $0 + ($1.value ? 1 : 0) }))/\(settingsDictionary().keys.count)")
          }
          
          Toggle("Prediction Notifications", isOn: $realTimeAlerts)
            .tint(colorScheme.themeColor(for: .brandColor))
          
          Toggle("Daily Outlook", isOn: $dailyOutlookAlerts)
            .onChange(of: dailyOutlookAlerts, perform: dailyOutlookAlertsChanged)
            .tint(colorScheme.themeColor(for: .brandColor))
          
          DatePicker("Daily Outlook Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
            .disabled(!dailyOutlookAlerts)
        }
        
        // Information
        Section("General") {
          Picker("Measurement System", selection: $measurementSystem) {
            Text(MeasurementSystem.metric.title).tag(MeasurementSystem.metric)
            Text(MeasurementSystem.imperial.title).tag(MeasurementSystem.imperial)
          }
          
          NavigationLink {
            ColorSchemePicker()
          } label: {
            HStack {
              Text("Theme")
              ColorSchemeView(scheme: colorScheme, titleAlignment: .trailing)
                .foregroundColor(.secondary)
                .id(colorScheme)
            }
          }
          
          Toggle("Dim Screen", isOn: $shouldDimScreen)
            .tint(colorScheme.themeColor(for: .brandColor))
          
          Picker("Dimming Percent", selection: $screenDimPercent) {
            Text("25%").tag(0.25)
            Text("50%").tag(0.5)
            Text("75%").tag(0.75)
            Text("100%").tag(1.0)
          }
        }
         
        Section {
          Button("Report Bug", action: reportBug)
          
          Button("Share Feedback", action: shareFeedback)
          
          Toggle("Submit Crash Data", isOn: $enableCrashReporting)
            .onChange(of: enableCrashReporting, perform: enableCrashReportingValueChanged)
            .tint(colorScheme.themeColor(for: .brandColor))
          
          SubtitleCell(title: "Version", subtitle: Bundle.main.humanReadableVersionString)
        }
        
        // Debug
        #if DEBUG
        Section("Debug") {
          NavigationLink {
            DebugSettingsView()
          } label: {
            Text("Debug Settings")
          }
        }
        #endif
      }
      .navigationTitle("Settings")
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .sheet(isPresented: $showingReportBug, onDismiss: nil) {
      FeedbackView(type: .bug)
    }
    .sheet(isPresented: $showingShareFeedback, onDismiss: nil) {
      FeedbackView(type: .feedback)
    }
  }
  
}

extension SettingsView {
  
  private func reportBug() {
    withAnimation {
      showingReportBug = true
    }
  }
  
  private func shareFeedback() {
    withAnimation {
      showingShareFeedback = true
    }
  }
  
  /// Called when the `dailyOutlookAlerts` setting changes.
  ///
  /// - Parameter newValue: The new `dailyOutlookAlerts` value.
  private func dailyOutlookAlertsChanged(_ newValue: Bool) {
    if newValue {
      Task {
        do {
          try await refresher.scheduleOutlookRefreshTask()
        }
        catch {
          logError("Error scheduling outlook refresh task: \(error)")
        }
      }
    }
    else {
      refresher.cancelOutlookRefreshTask()
    }
  }
  
  /// Turns crash reporting on or off.
  private func enableCrashReportingValueChanged(_ newValue: Bool) {
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(newValue)
  }
  
  private func settingsDictionary() -> [String: Bool] {
    return [
      AppSettings.Predictors.secondsSinceMidnight: predictorSecondsSinceMidnight,
      AppSettings.Predictors.weekday: predictorWeekday,
      AppSettings.Predictors.mindfulSession: predictorMindfulSession,
      AppSettings.Predictors.sleepSeconds: predictorSleepSeconds,
      AppSettings.Predictors.sleepOnset: predictorSleepOnset,
      AppSettings.Predictors.headphoneAudioExposure: predictorHeadphoneAudioExposure,
      AppSettings.Predictors.stepCount: predictorStepCount,
      AppSettings.Predictors.barometricPressure: predictorBarometricPressure,
      AppSettings.Predictors.humidity: predictorHumidity,
      AppSettings.Predictors.temperature: predictorTemperature,
      AppSettings.Predictors.environmentalAudioExposure: predictorEnvironmentalAudioExposure,
      AppSettings.Predictors.heartRate: predictorHeartRate,
      AppSettings.Predictors.respiratoryRate: predictorRespiratoryRate,
      AppSettings.Predictors.oxygenSaturation: predictorOxygenSaturation,
      AppSettings.Predictors.heartRateVariability: predictorHeartRateVariability,
      AppSettings.Predictors.walkingHeartRateAverage: predictorWalkingHeartRateAverage,
      AppSettings.Predictors.restingHeartRate: predictorRestingHeartRate
    ]
  }
  
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .environmentObject(Previewing.alertManager)
  }
}
