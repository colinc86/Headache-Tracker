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
  
  /// The view's initial settings.
  @State private var initialSettings = [String: Bool]()
  
  /// Whether the view is showing an alert.
  @State private var showingAlert = false
  
  var body: some View {
    Form {
      Section {
        ToggleCell(title: "Steps", data: .stepCount, state: $predictorStepCount, systemName: "figure.walk", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Activity")
      }
      
      Section {
        ToggleCell(title: "Heart Rate", data: .heartRate, state: $predictorHeartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Heart Rate Variability", data: .heartRateVariabilitySDNN, state: $predictorHeartRateVariability, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Oxygen Saturation", data: .oxygenSaturation, state: $predictorOxygenSaturation, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Resting Heart Rate", data: .restingHeartRate, state: $predictorRestingHeartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Respiratory Rate", data: .respiratoryRate, state: $predictorRespiratoryRate, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Walking Heart Rate", data: .walkingHeartRateAverage, state: $predictorWalkingHeartRateAverage, systemName: "heart", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Body")
      }
      
      Section {
        ToggleCell(title: "Mindful Duration", data: .mindfulSession, state: $predictorMindfulSession, systemName: "brain", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Mind")
      }
      
      Section {
        ToggleCell(title: "Sleep Duration", data: .sleepSeconds, state: $predictorSleepSeconds, systemName: "timer", valueChanged: updateSetting)
        ToggleCell(title: "Onset", data: .sleepOnset, state: $predictorSleepOnset, systemName: "clock", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sleep")
      }
      
      Section {
        ToggleCell(title: "Environmental Audio Level", data: .environmentalAudioExposure, state: $predictorEnvironmentalAudioExposure, systemName: "speaker", valueChanged: updateSetting)
        ToggleCell(title: "Headphone Audio Level", data: .headphoneAudioExposure, state: $predictorHeadphoneAudioExposure, systemName: "headphones", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sound")
      }
      
      Section {
        ToggleCell(title: "Day of Week", state: $predictorWeekday, systemName: "calendar")
        ToggleCell(title: "Time of Day", state: $predictorSecondsSinceMidnight, systemName: "clock")
      } header: {
        SectionTitleView(title: "Time")
      }
      
      Section {
        ToggleCell(title: "Barometric Pressure", state: $predictorBarometricPressure, systemName: "barometer")
        ToggleCell(title: "Humidity", state: $predictorHumidity, systemName: "humidity")
        ToggleCell(title: "Temperature", state: $predictorTemperature, systemName: "thermometer")
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
    initialSettings = settingsDictionary()
  }
  
  /// Called when the view disappears.
  func disappeared() {
    if initialSettings != settingsDictionary() {
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
  
  /// Gets the current settings dictionary.
  func settingsDictionary() -> [String: Bool] {
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
