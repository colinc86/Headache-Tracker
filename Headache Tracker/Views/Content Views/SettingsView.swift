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
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
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
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) private var dailyOutlookAlerts = false
  
  /// The daily outlook alert time.
  @AppStorage(AppSettings.dailyOutlookTime) private var dailyOutlookTime = TimeInterval(28800.0)
  
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
  
  /// The binding to modify the daily outlook time.
  var dailyOutlookDate: Binding<Date> {
    Binding<Date> {
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(dailyOutlookTime)
    } set: { newValue in
      dailyOutlookTime = Calendar.current.timeIntervalSinceMidnight(newValue)
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
        Section {
          if predictor.training {
            HStack {
              Text("Learn and Predict")
              Spacer()
              ProgressView()
                .progressViewStyle(DefaultProgressViewStyle())
            }
          }
          else {
            Toggle(isOn: $learnAndPredict) {
              Text("Learn and Predict")
            }
            .onChange(of: learnAndPredict, perform: learnAndPredictChanged)
          }
        } header: {
          Text("Prediction")
        } footer: {
          Text("Models last updated at \(predictor.modelUpdatedAt?.formatted() ?? "N/A")")
        }
        
        // Notifications
        Section {
          if learnAndPredict {
            Toggle(isOn: $dailyOutlookAlerts) {
              Text("Daily Outlook")
            }
            .onChange(of: dailyOutlookAlerts, perform: dailyOutlookAlertsChanged)
            
            DatePicker("Daily Outlook Time", selection: dailyOutlookDate, displayedComponents: .hourAndMinute)
              .disabled(!dailyOutlookAlerts)
            
            Toggle(isOn: $realTimeAlerts) {
              Text("Hourly Predictions")
            }
            .onChange(of: realTimeAlerts, perform: realTimeAlertsChanged)
          }
          
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
        
        // Debug
        Section("Debug") {
          Button("Train Models") {
            headacheManager.trainClassifiers { error in
              if let error = error {
                logError("Error training classifiers: \(error)")
              }
            }
          }
          
          Button("Clean Data") {
            headacheManager.cleanTrainingData { error in
              if let error = error {
                logError("Error cleaning data: \(error)")
              }
            }
          }
        }
      }
      .navigationTitle("Settings")
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
  
}

extension SettingsView {
  
  /// Called when the `learnAndPredict` setting changes.
  ///
  /// - Parameter newValue: The new `learnAndPredict` value.
  private func learnAndPredictChanged(_ newValue: Bool) {
    if newValue {
      headacheManager.scheduleTrainingRefreshTask()
      headacheManager.trainClassifiers { error in
        if let error = error {
          logError("Error training classifiers: \(error)")
        }
      }
    }
    else {
      headacheManager.cancelTrainingProcessingTask()
      headacheManager.resetPrediction()
    }
  }
  
  /// Called when the `dailyOutlookAlerts` setting changes.
  ///
  /// - Parameter newValue: The new `dailyOutlookAlerts` value.
  private func dailyOutlookAlertsChanged(_ newValue: Bool) {
    if newValue && learnAndPredict {
      headacheManager.scheduleOutlookRefreshTask()
    }
    else {
      headacheManager.cancelOutlookRefreshTask()
    }
  }
  
  /// Called when the `realTimeAlerts` setting changes.
  ///
  /// - Parameter newValue: The new `realTimeAlerts` value.
  private func realTimeAlertsChanged(_ newValue: Bool) {
    if newValue && learnAndPredict {
      headacheManager.schedulePredictionRefreshTask()
    }
    else {
      headacheManager.cancelPredictionRefreshTask()
    }
  }
  
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .environmentObject(Previewing.alertManager)
  }
}
