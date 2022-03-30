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
  
  /// The view's general settings.
  @Environment(\.generalSettings) private var generalSettings
  
  /// The view's health settings.
  @Environment(\.healthSettings) private var healthSettings
  
  /// The view's notification settings.
  @Environment(\.notificationSettings) private var notificationSettings
  
  /// The view's headache settings.
  @Environment(\.headacheSettings) private var headacheSettings
  
  /// The view's prediction settings.
  @Environment(\.predictionSettings) private var predictionSettings
  
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
      return !healthKitManager.needsAuthorization() && healthSettings.enabled
    } set: { newValue in
      healthSettings.enabled = newValue
      if  healthSettings.enabled {
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
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(notificationSettings.dailyOutlookTime)
    } set: { newValue in
      notificationSettings.dailyOutlookTime = Calendar.current.timeIntervalSinceMidnight(newValue)
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
          Toggle("Health App Integration", isOn: healthSettings.$enabled)
            .tint(generalSettings.colorTheme.baseColor)
          
          Picker("Delete Health Data", selection: healthSettings.$deleteDisposition) {
            ForEach(HeadacheManager.DeleteDisposition.allCases) { disposition in
              Text(disposition.rawValue.capitalized).tag(disposition)
            }
          }
        }
        
        // Headaches
        Section("Headaches") {
          Picker("Default Class", selection: headacheSettings.$defaultHeadacheClassification) {
            Text(Headache.Classification.primary.title).tag(Headache.Classification.primary)
            Text(Headache.Classification.secondary.title).tag(Headache.Classification.secondary)
          }
          
          Picker("Default Type", selection: headacheSettings.$defaultHeadacheType) {
            ForEach(Headache.Types.definedCases) { type in
              Text(type.title).tag(type)
            }
            ForEach(SharedUserDefaults.standard.customTypes) { type in
              Text(type.title).tag(type)
            }
          }
          
          Toggle("Check-Ins", isOn: notificationSettings.$checkInAlerts)
            .tint(generalSettings.colorTheme.baseColor)
            .disabled(alertsDenied)
          
          Picker("Check-In Interval", selection: notificationSettings.$checkInInterval) {
            ForEach(1 ..< 25) { i in
              Text("\(i) Hour\(i > 1 ? "s" : "")").tag(TimeInterval(i) * 3600.0)
            }
          }
          .disabled(!notificationSettings.checkInAlerts)
          .disabled(alertsDenied)
        }
        
        // Predictions
        Section("Predictions") {
          NavigationLink {
            PredictorsView()
          } label: {
            SubtitleCell(title: "My Predictors", subtitle: "\(predictionSettings.settingsDictionary().reduce(0, { $0 + ($1.value ? 1 : 0) }))/\(predictionSettings.settingsDictionary().keys.count)")
          }
          
          Toggle("Prediction Notifications", isOn: notificationSettings.$realTimeAlerts)
            .tint(generalSettings.colorTheme.baseColor)
          
          Toggle("Daily Outlook", isOn: notificationSettings.$dailyOutlookAlerts)
            .onChange(of: notificationSettings.dailyOutlookAlerts, perform: dailyOutlookAlertsChanged)
            .tint(generalSettings.colorTheme.baseColor)
          
          DatePicker("Daily Outlook Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
            .disabled(!notificationSettings.dailyOutlookAlerts)
        }
        
        // Information
        Section("General") {
          Picker("Measurement System", selection: generalSettings.$measurementSystem) {
            Text(MeasurementSystem.metric.title).tag(MeasurementSystem.metric)
            Text(MeasurementSystem.imperial.title).tag(MeasurementSystem.imperial)
          }
          
          NavigationLink {
            ColorThemePicker(theme: generalSettings.$colorTheme)
          } label: {
            HStack {
              Text("Theme")
              ColorThemeView(theme: generalSettings.colorTheme, titleAlignment: .trailing)
                .foregroundColor(.secondary)
                .id(generalSettings.colorTheme)
            }
          }
          
          Toggle("Dim Screen", isOn: generalSettings.$shouldDimScreen)
            .tint(generalSettings.colorTheme.baseColor)
          
          Picker("Dimming Percent", selection: generalSettings.$screenDimPercent) {
            Text("25%").tag(0.25)
            Text("50%").tag(0.5)
            Text("75%").tag(0.75)
            Text("100%").tag(1.0)
          }
        }
         
        Section {
          Button("Report Bug", action: reportBug)
          
          Button("Share Feedback", action: shareFeedback)
          
          Toggle("Submit Crash Data", isOn: generalSettings.$crashReportingEnabled)
            .onChange(of: generalSettings.crashReportingEnabled, perform: enableCrashReportingValueChanged)
            .tint(generalSettings.colorTheme.baseColor)
          
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
