//
//  DurationiView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct DurationView: View {
  
  @StateObject var headache: Headache
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// A timer to update the duration view for unresolved headaches.
  @State private var durationUpdateTimer: Timer?
  
  var body: some View {
    Text(Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "N/A")
      .font(.title)
      .id(durationID)
      .onAppear(perform: appeared)
      .onDisappear(perform: disappeared)
  }
  
}

extension DurationView {
  
  /// Updates the duration view's identifier.
  func updateDurationID() {
    DispatchQueue.main.async {
      withAnimation { durationID = UUID() }
    }
  }
  
  /// Called when the view appears.
  func appeared() {
    // If the headache isn't resolved, then start an update timer
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
    updateDurationID()
  }
  
}

struct DurationView_Previews: PreviewProvider {
  static var previews: some View {
    DurationView(headache: Previewing.CoreData.headache)
  }
}
