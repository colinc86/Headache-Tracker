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
  @AppStorage(Preferences.Predictors.Keys.dietaryCaffeine) var dietaryCaffeine = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.dietaryWater) var dietaryWater = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.timeInDaylight) var timeInDaylight = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.exerciseMinutes) var exerciseMinutes = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.menstrualCycle) var menstrualCycle = Preferences.Predictors.Defaults.optIn
  @AppStorage(Preferences.Predictors.Keys.humidity) var humidity = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.temperature) var temperature = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.bodyTemperature) var bodyTemperature = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.wristTemperature) var wristTemperature = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.basalBodyTemperature) var basalBodyTemperature = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.baselineRelative) var baselineRelative = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.beatToBeatHRV) var beatToBeatHRV = Preferences.Predictors.Defaults.enabled
  @AppStorage(Preferences.Predictors.Keys.temporalContext) var temporalContext = Preferences.Predictors.Defaults.enabled
  
  /// The view's initial settings.
  @State private var initialSettings = [String: Bool]()

  var body: some View {
    Form {
      Section {
        ToggleCell(title: "Steps", data: .stepCount, state: $stepCount, systemName: "figure.walk", valueChanged: updateSetting)
        ToggleCell(title: "Exercise Minutes", data: .appleExerciseTime, state: $exerciseMinutes, systemName: "figure.run", valueChanged: updateSetting)
        ToggleCell(title: "Time in Daylight", data: .timeInDaylight, state: $timeInDaylight, systemName: "sun.max", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Activity")
      }

      Section {
        ToggleCell(title: "Caffeine", data: .dietaryCaffeine, state: $dietaryCaffeine, systemName: "cup.and.saucer", valueChanged: updateSetting)
        ToggleCell(title: "Water", data: .dietaryWater, state: $dietaryWater, systemName: "drop", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Nutrition")
      } footer: {
        SectionFooterView(title: "Logged in the Health app or by other apps.")
      }

      Section {
        ToggleCell(title: "Menstrual Cycle", data: .menstrualDaysSinceCycleStart, state: $menstrualCycle, systemName: "calendar.circle", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Cycle")
      } footer: {
        SectionFooterView(title: "Off by default. Turning this on asks for read access to menstrual data and includes cycle timing in your insights.")
      }
      
      Section {
        ToggleCell(title: "Heart Rate", data: .heartRate, state: $heartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Heart Rate Variability", data: .heartRateVariabilitySDNN, state: $heartRateVariability, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Oxygen Saturation", data: .oxygenSaturation, state: $oxygenSaturation, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Resting Heart Rate", data: .restingHeartRate, state: $restingHeartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Respiratory Rate", data: .respiratoryRate, state: $respiratoryRate, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Walking Heart Rate", data: .walkingHeartRateAverage, state: $walkingHeartRateAverage, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Body Temperature", data: .bodyTemperature, state: $bodyTemperature, systemName: "thermometer.medium", valueChanged: updateSetting)
        ToggleCell(title: "Wrist Temperature", data: .wristTemperature, state: $wristTemperature, systemName: "thermometer.medium", valueChanged: updateSetting)
        ToggleCell(title: "Basal Body Temperature", data: .basalBodyTemperature, state: $basalBodyTemperature, systemName: "thermometer.medium", valueChanged: updateSetting)
        ToggleCell(title: "Beat-to-Beat HRV", state: $beatToBeatHRV, systemName: "waveform.path.ecg.rectangle")
      } header: {
        SectionTitleView(title: "Body")
      } footer: {
        SectionFooterView(title: "Temperature from a compatible ring or Apple Watch, and beat-to-beat HRV (RMSSD, pNN50, LF/HF) from the Watch's background readings. Deviation from your own baseline is a known migraine prodrome signal.")
      }
      
      Section {
        ToggleCell(title: "Deviation from Baseline", state: $baselineRelative, systemName: "waveform.path.ecg")
        ToggleCell(title: "Recent Trend", state: $temporalContext, systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
      } header: {
        SectionTitleView(title: "Sensitivity")
      } footer: {
        SectionFooterView(title: "Also feed the model how far your heart-rate variability, resting rate, breathing, sleep, and temperature stray from your own recent normal — the autonomic shift that often precedes a headache. Recent Trend adds each signal's swing over the last two days and its drift from its 24-hour average.")
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

        // The correlation engine reads the toggles too, so a change makes the
        // cached insights report wrong. Recompute now rather than waiting for
        // it to age out, so the Analyze tab is right on the way back.
        do {
          _ = try await headacheManager.computeInsights()
        }
        catch {
          logError("Error computing insights: \(error)")
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
    NavigationStack {
      PredictorsView()
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
        .environmentObject(Previewing.Prediction.predictor)
        .environmentObject(Previewing.healthKitManager)
    }
  }
}
