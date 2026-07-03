//
//  SettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

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
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  @AppStorage(Preferences.General.Keys.measurementSystem, store: .shared) private var measurementSystem = Preferences.General.Defaults.measurementSystem
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
  @AppStorage(Preferences.Notifications.Keys.checkInReminderAlerts) private var checkInReminderAlerts = Preferences.Notifications.Defaults.checkInReminderAlerts
  @AppStorage(Preferences.Notifications.Keys.checkInReminderTime) private var checkInReminderTime = Preferences.Notifications.Defaults.checkInReminderTime
  
  /// The headaches fetch request.
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
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

  /// The binding to modify the check-in reminder time.
  private var checkInReminderDate: Binding<Date> {
    Binding<Date> {
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(checkInReminderTime)
    } set: { newValue in
      checkInReminderTime = Calendar.current.timeIntervalSinceMidnight(newValue)
    }
  }
  
  /// Whether or not alerts are authorized.
  private var alertsDenied: Bool {
    return alertManager.authorizationStatus == .notDetermined || alertManager.authorizationStatus == .denied
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
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
            ForEach(Preferences().shared.customTypes) { type in
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
            SubtitleCell(title: "My Predictors", subtitle: "\(Preferences().predictors.settingsDictionary().reduce(0, { $0 + ($1.value ? 1 : 0) }))/\(Preferences().predictors.settingsDictionary().keys.count)")
          }
          
          Toggle("Prediction Notifications", isOn: $realTimeAlerts)
            .tint(colorTheme.baseColor)
          
          Toggle("Morning Brief", isOn: $dailyOutlookAlerts)
            .tint(colorTheme.baseColor)
          
          DatePicker("Morning Brief Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
            .disabled(!dailyOutlookAlerts)
        }

        // Daily check-in
        Section {
          Toggle("Check-In Reminder", isOn: $checkInReminderAlerts)
            .tint(colorTheme.baseColor)
            .disabled(alertsDenied)
            .onChange(of: checkInReminderAlerts) { _, _ in rescheduleCheckInReminder() }

          DatePicker("Reminder Time", selection: checkInReminderDate, displayedComponents: .hourAndMinute)
            .disabled(!checkInReminderAlerts)
            .onChange(of: checkInReminderTime) { _, _ in rescheduleCheckInReminder() }
        } header: {
          SectionTitleView(title: "Daily Check-In")
        } footer: {
          SectionFooterView(title: "An evening nudge to log the day's exposures.")
        }
        
        // Information
        Section("General") {
          Picker("Measurement System", selection: $measurementSystem) {
            Text(MeasurementSystem.metric.title).tag(MeasurementSystem.metric)
            Text(MeasurementSystem.imperial.title).tag(MeasurementSystem.imperial)
          }
          
          NavigationLink {
            ColorThemePicker()
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

  /// Reschedules the evening check-in reminder to match preferences.
  private func rescheduleCheckInReminder() {
    Task {
      do {
        try await refresher.updateExposureReminderSchedule()
      }
      catch {
        logError("Error scheduling check-in reminder: \(error)")
      }
    }
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
