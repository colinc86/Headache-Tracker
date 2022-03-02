//
//  TrainingDataListView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/21/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct TrainingDataListView: View {
  
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
          TrainingDataView(trainingData: data)
        } label: {
          SubtitleCell(title: data.timestamp?.formattedNonRelative() ?? "N/A", subtitle: data.severity?.severity.title ?? "-")
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

extension TrainingDataListView {
  
  private func deleteTrainingData(offsets: IndexSet) {
    withAnimation {
      offsets.map { trainingData[$0] }.forEach({ element in
        element.severity?.removeFromTrainingData(element)
        viewContext.delete(element)
      })
    }
  }
  
}

struct TrainingDataListView_Previews: PreviewProvider {
  static var previews: some View {
    TrainingDataListView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}

