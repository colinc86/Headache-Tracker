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
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// A timer to update the duration view for unresolved headaches.
  @State private var durationUpdateTimer: Timer?
  
  /// The date the view appeared.
  @State private var startDate: Date = Date()
  
  /// The amount of time to remove from the duration
  @State private var decrement: TimeInterval = 0.0
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(Formatters.dateComponentsFormatter.string(from: duration - decrement) ?? "N/A")
        .font(.title)
        .id(durationID)
      Text("Until " + Date().addingTimeInterval(duration).formattedRelative())
        .font(Font.subheadline)
        .foregroundColor(.secondary)
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: disappeared)
    .cell(title: "Duration", systemImage: "timer", foregroundColor: .green)
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
    startDate = Date()
    updateDurationID()
    startDurationUpdateTimer()
  }
  
  /// Called when the view disappears.
  func disappeared() {
    stopDurationUpdateTimer()
  }
  
  /// Starts the duration update timer.
  func startDurationUpdateTimer() {
    durationUpdateTimer = Timer(timeInterval: 60.0, repeats: true, block: durationUpdateTimerFired)
    durationUpdateTimer?.tolerance = 60.0 / 10.0
    RunLoop.main.add(durationUpdateTimer!, forMode: RunLoop.Mode.default)
  }
  
  /// Stops the duration update timer.
  func stopDurationUpdateTimer() {
    durationUpdateTimer?.invalidate()
    durationUpdateTimer = nil
  }
  
  /// Called when the duration update timer fires.
  func durationUpdateTimerFired(_ timer: Timer) {
    decrement = Date().timeIntervalSince(startDate)
    updateDurationID()
  }
  
}

struct DurationPredictionView_Previews: PreviewProvider {
  static var previews: some View {
    DurationPredictionView(duration: 0.0)
  }
}
