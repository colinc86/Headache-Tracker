//
//  TrainingDataView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/21/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct TrainingDataView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The application's training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    animation: .default)
  private var trainingData: FetchedResults<TrainingData>
  
  // MARK: View body
  
  var body: some View {
    List {
      ForEach(trainingData) { data in
        NavigationLink {
          List {
            Section {
              SubtitleCell(title: "Severity", subtitle: data.severity?.severity.title ?? "-")
              SubtitleCell(title: "Timestamp", subtitle: data.timestamp?.formatted() ?? "N/A")
            }
            
            Section {
              SubtitleCell(title: "Sleep", subtitle: Measurement(value: data.sleepSeconds, unit: UnitDuration.seconds).formatted())
              SubtitleCell(title: "Oxygen Saturation", subtitle: String(format: "%0.f%%", data.oxygenSaturation * 100.0))
              SubtitleCell(title: "Heart Rate", subtitle: String(format: "%0.f%%", data.oxygenSaturation * 100.0))
            }
            
            Section {
              SubtitleCell(title: "Barometric Pressure", subtitle: data.barometicPressureMeasurement.formatted())
              SubtitleCell(title: "Current Pressure", subtitle: data.currentPressureMeasurement.formatted())
              SubtitleCell(title: "Current Humidity", subtitle: String(format: "%0.f%%", data.currentHumidity * 100.0))
              SubtitleCell(title: "Current Temperature", subtitle: data.currentTemperatureMeasurement.formatted())
              SubtitleCell(title: "𝚺 Pressure", subtitle: "\(data.sigmaPressure) kPa")
              SubtitleCell(title: "𝚺 Humidity", subtitle: String(format: "%0.f%%", data.sigmaHumidity * 100.0))
              SubtitleCell(title: "𝚺 Temperature", subtitle: "\(data.sigmaTemperature)℃")
            }
          }
        } label: {
          SubtitleCell(title: data.timestamp?.formatted(date: .numeric, time: .shortened) ?? "N/A", subtitle: data.severity?.severity.title ?? "-")
        }
      }
      .onDelete(perform: deleteTrainingData)
    }
    .navigationTitle("Training Data")
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        EditButton()
      }
    }
  }
  
}

// MARK: Private methods

extension TrainingDataView {
  
  private func deleteTrainingData(offsets: IndexSet) {
    withAnimation {
      offsets.map { trainingData[$0] }.forEach({ viewContext.delete($0) })
    }
  }
  
}

struct TrainingDataView_Previews: PreviewProvider {
  static var previews: some View {
    TrainingDataView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
}

