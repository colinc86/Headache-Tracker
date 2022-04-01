//
//  PredictorsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/15/22.
//

import SwiftUI

struct PredictorsView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The health kit manager.
  @EnvironmentObject private var healthKitManager: HealthKitManager
  
  // Preferences
  @AppStorage(Preferences.Predictors.Keys.stepCount) var stepCount = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.heartRate) var heartRate = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.heartRateVariability) var heartRateVariability = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.oxygenSaturation) var oxygenSaturation = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.restingHeartRate) var restingHeartRate = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.respiratoryRate) var respiratoryRate = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.walkingHeartRateAverage) var walkingHeartRateAverage = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.mindfulSession) var mindfulSession = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.sleepSeconds) var sleepSeconds = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.sleepOnset) var sleepOnset = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.environmentalAudioExposure) var environmentalAudioExposure = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.headphoneAudioExposure) var headphoneAudioExposure = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.weekday) var weekday = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.secondsSinceMidnight) var secondsSinceMidnight = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.barometricPressure) var barometricPressure = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.humidity) var humidity = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.temperature) var temperature = Preferences.Predictors.Defaults.enabled
  
  /// The view's initial settings.
  @State private var initialSettings = [String: Bool]()
  
  /// Whether the view is showing an alert.
  @State private var showingAlert = false
  
  var body: some View {
    Form {
      Section {
        ToggleCell(title: "Steps", data: .stepCount, state: $stepCount, systemName: "figure.walk", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Activity")
      }
      
      Section {
        ToggleCell(title: "Heart Rate", data: .heartRate, state: $heartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Heart Rate Variability", data: .heartRateVariabilitySDNN, state: $heartRateVariability, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Oxygen Saturation", data: .oxygenSaturation, state: $oxygenSaturation, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Resting Heart Rate", data: .restingHeartRate, state: $restingHeartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Respiratory Rate", data: .respiratoryRate, state: $respiratoryRate, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Walking Heart Rate", data: .walkingHeartRateAverage, state: $walkingHeartRateAverage, systemName: "heart", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Body")
      }
      
      Section {
        ToggleCell(title: "Mindful Duration", data: .mindfulSession, state: $mindfulSession, systemName: "brain", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Mind")
      }
      
      Section {
        ToggleCell(title: "Sleep Duration", data: .sleepSeconds, state: $sleepSeconds, systemName: "timer", valueChanged: updateSetting)
        ToggleCell(title: "Onset", data: .sleepOnset, state: $sleepOnset, systemName: "clock", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sleep")
      }
      
      Section {
        ToggleCell(title: "Environmental Audio Level", data: .environmentalAudioExposure, state: $environmentalAudioExposure, systemName: "speaker", valueChanged: updateSetting)
        ToggleCell(title: "Headphone Audio Level", data: .headphoneAudioExposure, state: $headphoneAudioExposure, systemName: "headphones", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sound")
      }
      
      Section {
        ToggleCell(title: "Day of Week", state: $weekday, systemName: "calendar")
        ToggleCell(title: "Time of Day", state: $secondsSinceMidnight, systemName: "clock")
      } header: {
        SectionTitleView(title: "Time")
      }
      
      Section {
        ToggleCell(title: "Barometric Pressure", state: $barometricPressure, systemName: "barometer")
        ToggleCell(title: "Humidity", state: $humidity, systemName: "humidity")
        ToggleCell(title: "Temperature", state: $temperature, systemName: "thermometer")
      } header: {
        SectionTitleView(title: "Weather")
      }
    }
    .navigationTitle("My Predictors")
    .onAppear(perform: appeared)
    .onDisappear(perform: disappeared)
    .confirmationAlert(isPresented: $showingAlert, title: "Health Kit Data", message: "Visit the settings app to enable this data type.")
  }
}

extension PredictorsView {
  
  /// Called when the view appears.
  func appeared() {
    initialSettings = Preferences.Predictors().settingsDictionary()
  }
  
  /// Called when the view disappears.
  func disappeared() {
    if initialSettings != Preferences.Predictors().settingsDictionary() {
      Task {
        do {
          try await headacheManager.trainClassifiers()
        }
        catch {
          logError("Error training classifiers: \(error)")
        }
      }
    }
  }
  
  /// Updates the setting with the given health kit data.
  ///
  /// - Parameters:
  ///   - data: The health kit data.
  ///   - newValue: The new value.
  func updateSetting(_ data: HealthKitData?, newValue: Bool) {
    guard let data = data else {
      return
    }

    if newValue {
      switch healthKitManager.authorizationStatus(for: data) {
      case .notDetermined:
        Task {
          do {
            try await healthKitManager.authorize(for: data)
          }
          catch {
            logError("Error authorizing health kit data: \(error)")
          }
        }
      default:
        break
      }
    }
  }
  
}

struct PredictorsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      PredictorsView()
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
        .environmentObject(Previewing.Prediction.predictor)
        .environmentObject(Previewing.healthKitManager)
    }
  }
}
