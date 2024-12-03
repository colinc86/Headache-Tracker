//
//  TrainingDataView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct TrainingDataView: View {
  
  /// The training data to display.
  @StateObject var trainingData: TrainingData
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// Whether or not the view is editing.
  @State var editing: Bool = false
  
  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SubtitleCell(title: "Severity", subtitle: trainingData.severity?.severity.title ?? "-")
        SubtitleCell(title: "Timestamp", subtitle: trainingData.timestamp?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Health Data Version", subtitle: "\(trainingData.healthData?.version ?? "")")
        SubtitleCell(title: "Weather Version", subtitle: "\(trainingData.weatherData?.version ?? "")")
      }
      
      Section {
        SubtitleCell(title: "Sleep", subtitle: Measurement(value: trainingData.healthData?.sleepSeconds ?? 0.0, unit: UnitDuration.seconds).formatted())
        SubtitleCell(title: "Sleep Onset", subtitle: Measurement(value: trainingData.healthData?.sleepOnset ?? 0.0, unit: UnitDuration.seconds).formatted())
        SubtitleCell(title: "Oxygen Saturation", subtitle: String(format: "%0.f%%", (trainingData.healthData?.oxygenSaturation ?? 0.0) * 100.0))
        SubtitleCell(title: "Heart Rate", subtitle: "\(trainingData.healthData?.heartRate ?? 0.0)")
        SubtitleCell(title: "Heart Rate Variability", subtitle: "\(trainingData.healthData?.heartRateVariability ?? 0.0)")
        SubtitleCell(title: "Resting Heart Rate", subtitle: "\(trainingData.healthData?.restingHeartRate ?? 0.0)")
        SubtitleCell(title: "Respiratory Rate", subtitle: "\(trainingData.healthData?.respiratoryRate ?? 0.0)")
        SubtitleCell(title: "Walking Heart Rate", subtitle: "\(trainingData.healthData?.walkingHeartRateAverage ?? 0.0)")
        SubtitleCell(title: "Environmental Audio Exposure", subtitle: "\(trainingData.healthData?.environmentalAudioExposure ?? 0.0)")
        SubtitleCell(title: "Headphone Audio Exposure", subtitle: "\(trainingData.healthData?.headphoneAudioExposure ?? 0.0)")
        SubtitleCell(title: "Steps", subtitle: "\(trainingData.healthData?.stepCount ?? 0.0)")
        SubtitleCell(title: "Mindful Duration", subtitle: "\(trainingData.healthData?.mindfulSeconds ?? 0.0)")
      }
      
      Section {
        SubtitleCell(title: "Barometric Pressure", subtitle: trainingData.weatherData?.devicePressureMeasurement.formatted() ?? "N/A")
        SubtitleCell(title: "Current Pressure", subtitle: trainingData.weatherData?.pressureMeasurement.formatted() ?? "N/A")
        SubtitleCell(title: "Current Humidity", subtitle: trainingData.weatherData?.humidityMeasurement.converted(to: .percent).formatted() ?? "N/A")
        SubtitleCell(title: "Current Temperature", subtitle: trainingData.weatherData?.temperatureMeasurement.formatted() ?? "N/A")
        SubtitleCell(title: "𝚺 Pressure", subtitle: "\(trainingData.weatherData?.sigmaPressure ?? 0.0) kPa")
        SubtitleCell(title: "𝚺 Humidity", subtitle: String(format: "%0.f%%", (trainingData.weatherData?.sigmaHumidity ?? 0.0) * 100.0))
        SubtitleCell(title: "𝚺 Temperature", subtitle: "\(trainingData.weatherData?.sigmaTemperature ?? 0.0)℃")
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        if editing {
          Button("Cancel", action: cancel)
          Button("Save", action: save)
        }
        else {
          Button("Edit", action: edit)
        }
      }
    }
  }
  
}

extension TrainingDataView {
  
  private func save() {
    withAnimation {
      editing = false
      try? viewContext.save()
    }
  }
  
  private func cancel() {
    withAnimation {
      editing = false
      viewContext.refresh(trainingData, mergeChanges: false)
    }
  }
  
  private func edit() {
    withAnimation {
      editing = true
    }
  }
  
}
