//
//  SettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import SwiftUI
import Logger

/// Displays the application's settings.
struct SettingsView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The health kit manager.
  @EnvironmentObject private var healthKitManager: HealthKitManager
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The check-in alert setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The check-in interval setting to use when `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) private var learnAndPredict = false
    
  /// The health app integration binding.
  /// Will authorize health kit if set to true.
  var healthAppIntegration: Binding<Bool> {
    Binding<Bool> {
      return !healthKitManager.needsAuthorization() && healthIntegration
    } set: { newValue in
      healthIntegration = newValue
      if healthIntegration {
        healthKitManager.authorize { error in
          if let error = error {
            logError("Error authorizing HealthKit: \(error)")
          }
        }
      }
    }
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
        }
        
        // Learning and Prediction
        Section("Prediction") {
          Toggle(isOn: $learnAndPredict) {
            Text("Learn and Predict")
          }
//          Button("Reset") {
//            headacheManager.resetPrediction()
//          }
//          .disabled(!learnAndPredict)
        }
        .onChange(of: learnAndPredict, perform: learnAndPredictChanged)
        
        // Notifications
        Section {
          Toggle(isOn: $checkInAlerts) {
            Text("Check-Ins")
          }
          
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
          if alertManager.authorizationStatus == .notDetermined || alertManager.authorizationStatus == .denied {
            Text("Visit the Settings app to update the app's notification settings.")
          }
          else {
            Text("Send a notification to check in to the app the specified number of hours after your last update. The notification will only be sent once per update.")
          }
        }
        .disabled(alertManager.authorizationStatus == .notDetermined || alertManager.authorizationStatus == .denied)
        
        // Information
        Section {
          SubtitleCell(title: "Version", subtitle: Bundle.main.humanReadableVersionString)
        }
      }
      .navigationTitle("Settings")
    }
  }
  
}

extension SettingsView {
  
  func learnAndPredictChanged(_ newValue: Bool) {
    if newValue {
      logDebug("Motion manager current authorization status: \(MotionManager.authorizationStatus())")
    }
  }
  
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.healthKitManager)
      .environmentObject(Previewing.alertManager)
  }
}
