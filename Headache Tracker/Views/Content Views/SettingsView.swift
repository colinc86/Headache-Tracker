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
  
  /// Whether we are showing the bug report content view.
  @State private var showingReportBug = false
  
  /// Whether we are showing the share feedback view.
  @State private var showingShareFeedback = false
  
  // Preferences
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  @AppStorage(Preferences.General.Keys.measurementSystem) private var measurementSystem = Preferences.General.Defaults.measurementSystem
  @AppStorage(Preferences.General.Keys.shouldDimScreen) private var shouldDimScreen = Preferences.General.Defaults.shouldDimScreen
  @AppStorage(Preferences.General.Keys.screenDimPercent) private var screenDimPercent = Preferences.General.Defaults.screenDimPercent
  @AppStorage(Preferences.General.Keys.crashReportingEnabled) private var crashReportingEnabled = Preferences.General.Defaults.crashReportingEnabled
  @AppStorage(Preferences.Health.Keys.enabled) private var healthEnabled = Preferences.Health.Defaults.enabled
  @AppStorage(Preferences.Health.Keys.deleteDisposition) private var healthDeleteDisposition = Preferences.Health.Defaults.deleteDisposition
  @AppStorage(Preferences.Headaches.Keys.defaultHeadacheClassification) private var defaultHeadacheClassification = Preferences.Headaches.Defaults.defaultHeadacheClassification
  @AppStorage(Preferences.Headaches.Keys.defaultHeadacheType) private var defaultHeadacheType = Preferences.Headaches.Defaults.defaultHeadacheType
  @AppStorage(Preferences.Notifications.Keys.checkInAlerts) private var checkInAlerts = Preferences.Notifications.Defaults.checkInAlerts
  @AppStorage(Preferences.Notifications.Keys.checkInInterval) private var checkInInterval = Preferences.Notifications.Defaults.checkInInterval
  @AppStorage(Preferences.Notifications.Keys.realTimeAlerts) private var realTimeAlerts = Preferences.Notifications.Defaults.realTimeAlerts
  @AppStorage(Preferences.Notifications.Keys.dailyOutlookAlerts) private var dailyOutlookAlerts = Preferences.Notifications.Defaults.dailyOutlookAlerts
  @AppStorage(Preferences.Notifications.Keys.dailyOutlookTime) private var dailyOutlookTime = Preferences.Notifications.Defaults.dailyOutlookTime
  
  /// The headaches fetch request.
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The app preferences.
  private let preferences = Preferences()
  
  // MARK: Computed properties
    
  /// The health app integration binding.
  /// Will authorize health kit if set to true.
  private var healthAppIntegration: Binding<Bool> {
    Binding<Bool> {
      return !healthKitManager.needsAuthorization() && healthEnabled
    } set: { newValue in
      healthEnabled = newValue
      if  healthEnabled {
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
          Toggle("Health App Integration", isOn: $healthEnabled)
            .tint(colorTheme.baseColor)
          
          Picker("Delete Health Data", selection: $healthDeleteDisposition) {
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
            ForEach(preferences.shared.customTypes) { type in
              Text(type.title).tag(type)
            }
          }
          
          Toggle("Check-Ins", isOn: $checkInAlerts)
            .tint(colorTheme.baseColor)
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
            SubtitleCell(title: "My Predictors", subtitle: "\(preferences.predictors.settingsDictionary().reduce(0, { $0 + ($1.value ? 1 : 0) }))/\(preferences.predictors.settingsDictionary().keys.count)")
          }
          
          Toggle("Prediction Notifications", isOn: $realTimeAlerts)
            .tint(colorTheme.baseColor)
          
          Toggle("Daily Outlook", isOn: $dailyOutlookAlerts)
            .onChange(of: dailyOutlookAlerts, perform: dailyOutlookAlertsChanged)
            .tint(colorTheme.baseColor)
          
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
            ColorThemePicker(theme: $colorTheme)
          } label: {
            HStack {
              Text("Theme")
              ColorThemeView(theme: colorTheme, titleAlignment: .trailing)
                .foregroundColor(.secondary)
                .id(colorTheme)
            }
          }
          
          Toggle("Dim Screen", isOn: $shouldDimScreen)
            .tint(colorTheme.baseColor)
          
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
          
          Toggle("Submit Crash Data", isOn: $crashReportingEnabled)
            .onChange(of: crashReportingEnabled, perform: enableCrashReportingValueChanged)
            .tint(colorTheme.baseColor)
          
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
