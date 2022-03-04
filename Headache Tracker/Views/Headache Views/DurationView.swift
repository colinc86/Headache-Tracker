//
//  DurationiView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct DurationView: View {
  
  /// The headache to display.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// A timer to update the duration view for unresolved headaches.
  @State private var durationUpdateTimer: Timer?
  
  private var caption: String? {
    if headache.resolved, let endTime = headache.endTime {
      return "until " + endTime.formattedNonRelative()
    }
    return nil
  }
  
  var body: some View {
    TitleCaptionView(title: "Duration", systemImage: "timer", foregroundColor: .green, caption: caption) {
      VStack(alignment: .leading) {
        Text(Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "N/A")
          .font(.title)
          .id(durationID)
        
        if headache.resolved, let endTime = headache.endTime {
          Text("until " + endTime.formattedNonRelative())
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
    }
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
    if !headache.resolved {
      updateDurationID()
      startDurationUpdateTimer()
    }
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
    DurationView(headache: Previewing.CoreData.resolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
