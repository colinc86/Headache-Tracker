//
//  TrainingDataView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct TrainingDataView: View {
  
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
        SubtitleCell(title: "Data Version", subtitle: "\(trainingData.version ?? "")")
      }
      
      Section {
        SubtitleCell(title: "Sleep", subtitle: Measurement(value: trainingData.sleepSeconds, unit: UnitDuration.seconds).formatted())
        SubtitleCell(title: "Oxygen Saturation", subtitle: String(format: "%0.f%%", trainingData.oxygenSaturation * 100.0))
        SubtitleCell(title: "Heart Rate", subtitle: "\(trainingData.heartRate)")
      }
      
      Section {
        if editing {
          TextField("Barometric Pressure", value: $trainingData.barometricPressure, format: .number, prompt: Text("Barometric Pressure"))
          TextField("Current Pressure", value: $trainingData.currentPressure, format: .number, prompt: Text("Current Pressure"))
          TextField("Current Humidity", value: $trainingData.currentHumidity, format: .number, prompt: Text("Current Humidity"))
          TextField("Current Temperature", value: $trainingData.currentTemperature, format: .number, prompt: Text("Current Temperature"))
          TextField("𝚺 Pressure", value: $trainingData.sigmaPressure, format: .number, prompt: Text("𝚺 Pressure"))
          TextField("𝚺 Humidity", value: $trainingData.sigmaHumidity, format: .number, prompt: Text("𝚺 Humidity"))
          TextField("𝚺 Temperature", value: $trainingData.sigmaTemperature, format: .number, prompt: Text("𝚺 Temperature"))
        }
        else {
          SubtitleCell(title: "Barometric Pressure", subtitle: trainingData.pressureMeasurement.formatted())
          SubtitleCell(title: "Current Pressure", subtitle: trainingData.devicePressureMeasurement.formatted())
          SubtitleCell(title: "Current Humidity", subtitle: trainingData.humidityMeasurement.formatted())
          SubtitleCell(title: "Current Temperature", subtitle: trainingData.temperatureMeasurement.formatted())
          SubtitleCell(title: "𝚺 Pressure", subtitle: "\(trainingData.sigmaPressure) kPa")
          SubtitleCell(title: "𝚺 Humidity", subtitle: String(format: "%0.f%%", trainingData.sigmaHumidity * 100.0))
          SubtitleCell(title: "𝚺 Temperature", subtitle: "\(trainingData.sigmaTemperature)℃")
        }
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
