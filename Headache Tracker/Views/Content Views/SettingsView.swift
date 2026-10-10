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
  @AppStorage(Preferences.General.Keys.aiSummaries) private var aiSummaries = Preferences.General.Defaults.aiSummaries

  /// The written summaries, for the Apple Intelligence setting.
  @EnvironmentObject private var summaryService: SummaryService
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
  
  // MARK: Computed properties
    
  /// The health app integration binding: reflects the stored preference and
  /// requests HealthKit authorization the moment it's switched on, so the
  /// permission prompt appears immediately rather than only on the next launch.
  private var healthAppIntegration: Binding<Bool> {
    Binding<Bool> {
      return healthEnabled
    } set: { newValue in
      healthEnabled = newValue
      if newValue {
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

  /// Whether the sync-enable confirmation is showing.
  @State private var showingSyncConfirmation = false

  /// Whether the relaunch-required alert is showing.
  @State private var showingRelaunchAlert = false

  /// The sync preference (read at store setup; not @AppStorage because
  /// changes only apply on relaunch anyway).
  @State private var syncEnabled = Preferences.Sync().enabled

  /// The toggle binding: enabling asks for confirmation first; either
  /// direction requires a relaunch.
  private var syncToggleBinding: Binding<Bool> {
    Binding {
      syncEnabled
    } set: { newValue in
      if newValue {
        showingSyncConfirmation = true
      }
      else {
        var sync = Preferences.Sync()
        sync.enabled = false
        syncEnabled = false
        showingRelaunchAlert = true
      }
    }
  }

  /// Whether or not alerts are authorized.
  private var alertsDenied: Bool {
    return alertManager.authorizationStatus == .notDetermined || alertManager.authorizationStatus == .denied
  }

  /// "enabled/total" predictors, for the My Predictors cell subtitle.
  private var predictorsSummary: String {
    let settings = Preferences().predictors.settingsDictionary()
    let enabled = settings.values.lazy.filter({ $0 }).count
    return "\(enabled)/\(settings.count)"
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
      Form {
        // Integrations
        Section("Integrations") {
          Toggle("Health App Integration", isOn: healthAppIntegration)
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
            SubtitleCell(title: "My Predictors", subtitle: predictorsSummary)
          }
          
          Toggle("Prediction Notifications", isOn: $realTimeAlerts)
            .tint(colorTheme.baseColor)
            .disabled(alertsDenied)

          Toggle("Morning Brief", isOn: $dailyOutlookAlerts)
            .tint(colorTheme.baseColor)
            .disabled(alertsDenied)

          DatePicker("Morning Brief Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
            .disabled(!dailyOutlookAlerts)
            .disabled(alertsDenied)
        }

        // Data
        Section {
          NavigationLink {
            ExportView()
          } label: {
            Text("Export for Clinician")
          }

          Toggle("iCloud Sync", isOn: syncToggleBinding)
            .tint(colorTheme.baseColor)
        } header: {
          Text("Data")
        } footer: {
          Text("Sync your headaches, medications, and tags across devices. Prediction and training data stay on this device.")
        }

        // Apple Intelligence summaries
        Section {
          Toggle("Apple Intelligence Summaries", isOn: $aiSummaries)
            .tint(colorTheme.baseColor)
            .onChange(of: aiSummaries) { _, _ in summaryService.invalidate() }
        } header: {
          Text("Summaries")
        } footer: {
          Text(summariesFooter)
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
          .disabled(!shouldDimScreen)
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
    .confirmationDialog("Turn on iCloud Sync? Your headache log will upload to your private iCloud database. This splits the database into synced and device-only parts — turning sync off later stops uploads but keeps that layout.", isPresented: $showingSyncConfirmation, titleVisibility: .visible) {
      Button("Turn On Sync") {
        var sync = Preferences.Sync()
        sync.enabled = true
        sync.storeIsSplit = true
        syncEnabled = true
        showingRelaunchAlert = true
      }
    }
    .alert("Relaunch Required", isPresented: $showingRelaunchAlert) {
      Button("OK") {}
    } message: {
      Text("Quit and reopen the app for the sync change to take effect.")
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

}

extension SettingsView {

  /// What the summaries setting does, and why it can't run when it can't.
  var summariesFooter: String {
    let base = "The short explanations on Track and Profile are written on this device from your own data. Nothing leaves your phone."
    switch summaryService.availability {
    case .available:
      return base
    case .turnedOff:
      return base + " Off, simpler built-in wording is used."
    case .unavailable(let reason):
      return base + " " + reason + " Built-in wording is used until then."
    }
  }

}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environmentObject(SummaryService())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .environmentObject(Previewing.alertManager)
  }
}
