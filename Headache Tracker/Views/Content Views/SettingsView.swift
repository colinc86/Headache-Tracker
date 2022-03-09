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
  
  /// Whether or not to enable crash reporting.
  @AppStorage(AppSettings.enableCrashReporting) var enableCrashReporting = true
  
  /// The health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
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
  
  /// Whether we are showing the bug report content view.
  @State private var showingReportBug = false
  
  /// Whether we are showing the share feedback view.
  @State private var showingShareFeedback = false
  
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
          Toggle(isOn: healthAppIntegration) {
            Text("Health App Integration")
          }
          .tint(.accentColor)
        }
        
        // Notifications
        Section {
          Toggle(isOn: $dailyOutlookAlerts) {
            Text("Daily Outlook")
          }
          .onChange(of: dailyOutlookAlerts, perform: dailyOutlookAlertsChanged)
          .tint(.accentColor)
          
          DatePicker("Daily Outlook Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
            .disabled(!dailyOutlookAlerts)
          
          Toggle(isOn: $realTimeAlerts) {
            Text("Hourly Predictions")
          }
          .tint(.accentColor)
          
          Toggle(isOn: $checkInAlerts) {
            Text("Headache Check-Ins")
          }
          .tint(.accentColor)
          
          Picker(selection: $checkInInterval) {
            ForEach(1 ..< 25) { i in
              Text("\(i) Hour\(i > 1 ? "s" : "")").tag(TimeInterval(i) * 3600.0)
            }
          } label: {
            Text("Check-In Interval")
          }
          .disabled(!checkInAlerts)
        } header: {
          Text("Notifications")
        } footer: {
          if alertsDenied {
            Text("Visit the Settings app to update the app's notification settings.")
          }
          else {
            Text("Send a notification to check in to the app the specified number of hours after your last update. The notification will only be sent once per update.")
          }
        }
        .disabled(alertsDenied)
        
        // Information
        Section {
          Button("Report Bug", action: reportBug)
          
          Button("Share Feedback", action: shareFeedback)
          
          Toggle(isOn: $enableCrashReporting) {
            Text("Submit Crash Data")
          }
          .onChange(of: enableCrashReporting, perform: enableCrashReportingValueChanged)
          .tint(.accentColor)
          
          SubtitleCell(title: "Version", subtitle: Bundle.main.humanReadableVersionString)
        } header: {
          Text("General")
        }
        
        // Debug
        #if DEBUG
        Section {
          NavigationLink {
            DebugSettingsView()
          } label: {
            Text("Debug Settings")
          }
        } header: {
          Text("Debug")
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
