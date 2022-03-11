//
//  DurationPredictionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/18/22.
//

import UIKit
import SwiftUI

struct DurationPredictionView: View {
  
  /// The view's predicted duration.
  let duration: TimeInterval
  
  /// The prediction date.
  let date: Date
  
  // MARK: Private properties
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// The waiter responsible for updating the view's duration.
  private let durationUpdateWaiter = Waiter()
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: "Duration", systemImage: "timer", foregroundColor: .green, caption: "Until " + date.addingTimeInterval(duration).formattedRelative()) {
      Text(Formatters.dateComponentsFormatter.string(from: duration - Date().timeIntervalSince(date)) ?? "N/A")
        .font(.title)
        .id(durationID)
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: durationUpdateWaiter.stop)
  }
}

extension DurationPredictionView {
  
  /// Updates the duration view's identifier.
  func updateDurationID() {
    DispatchQueue.main.async {
      withAnimation { durationID = UUID() }
    }
  }
  
  /// Called when the view appears.
  func appeared() {
    updateDurationID()
    durationUpdateWaiter.wait(for: 60.0, repeats: true) {
      updateDurationID()
    }
  }
  
}

struct DurationPredictionView_Previews: PreviewProvider {
  static var previews: some View {
    DurationPredictionView(duration: 0.0, date: Date())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(.fixed(width: 428, height: 100))
  }
}
