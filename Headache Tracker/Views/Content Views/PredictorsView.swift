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
  
  /// The view's prediction settings.
  @Environment(\.predictionSettings) private var predictionSettings
  
  /// The view's initial settings.
  @State private var initialSettings = [String: Bool]()
  
  /// Whether the view is showing an alert.
  @State private var showingAlert = false
  
  var body: some View {
    Form {
      Section {
        ToggleCell(title: "Steps", data: .stepCount, state: predictionSettings.$stepCount, systemName: "figure.walk", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Activity")
      }
      
      Section {
        ToggleCell(title: "Heart Rate", data: .heartRate, state: predictionSettings.$heartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Heart Rate Variability", data: .heartRateVariabilitySDNN, state: predictionSettings.$heartRateVariability, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Oxygen Saturation", data: .oxygenSaturation, state: predictionSettings.$oxygenSaturation, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Resting Heart Rate", data: .restingHeartRate, state: predictionSettings.$restingHeartRate, systemName: "heart", valueChanged: updateSetting)
        ToggleCell(title: "Respiratory Rate", data: .respiratoryRate, state: predictionSettings.$respiratoryRate, systemName: "lungs", valueChanged: updateSetting)
        ToggleCell(title: "Walking Heart Rate", data: .walkingHeartRateAverage, state: predictionSettings.$walkingHeartRateAverage, systemName: "heart", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Body")
      }
      
      Section {
        ToggleCell(title: "Mindful Duration", data: .mindfulSession, state: predictionSettings.$mindfulSession, systemName: "brain", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Mind")
      }
      
      Section {
        ToggleCell(title: "Sleep Duration", data: .sleepSeconds, state: predictionSettings.$sleepSeconds, systemName: "timer", valueChanged: updateSetting)
        ToggleCell(title: "Onset", data: .sleepOnset, state: predictionSettings.$sleepOnset, systemName: "clock", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sleep")
      }
      
      Section {
        ToggleCell(title: "Environmental Audio Level", data: .environmentalAudioExposure, state: predictionSettings.$environmentalAudioExposure, systemName: "speaker", valueChanged: updateSetting)
        ToggleCell(title: "Headphone Audio Level", data: .headphoneAudioExposure, state: predictionSettings.$headphoneAudioExposure, systemName: "headphones", valueChanged: updateSetting)
      } header: {
        SectionTitleView(title: "Sound")
      }
      
      Section {
        ToggleCell(title: "Day of Week", state: predictionSettings.$weekday, systemName: "calendar")
        ToggleCell(title: "Time of Day", state: predictionSettings.$secondsSinceMidnight, systemName: "clock")
      } header: {
        SectionTitleView(title: "Time")
      }
      
      Section {
        ToggleCell(title: "Barometric Pressure", state: predictionSettings.$barometricPressure, systemName: "barometer")
        ToggleCell(title: "Humidity", state: predictionSettings.$humidity, systemName: "humidity")
        ToggleCell(title: "Temperature", state: predictionSettings.$temperature, systemName: "thermometer")
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
    initialSettings = predictionSettings.settingsDictionary()
  }
  
  /// Called when the view disappears.
  func disappeared() {
    if initialSettings != predictionSettings.settingsDictionary() {
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
