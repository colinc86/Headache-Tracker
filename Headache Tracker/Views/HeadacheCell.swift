//
//  HeadacheCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

/// Displays a headache in a cell view.
struct HeadacheCell: View {
  
  // MARK: Public properties
  
  /// The headache to display.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The id of the severity level view.
  @State private var severityID = UUID()
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// A timer to update the duration view for unresolved headaches.
  @State private var durationUpdateTimer: Timer?
  
  /// The previous severity range.
  @State private var previousSeverityRange: HealthKitManager.SeverityRange?
  
  // MARK: View body
  
  var body: some View {
    HStack(alignment: .top) {
      SeverityLevel(headache: headache)
        .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
        .frame(width: 20.0)
        .id(severityID)
      
      VStack {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formatted() ?? "N/A")
        Spacer(minLength: 0.0)
        SubtitleCell(title: "Duration", subtitle: Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "0 min")
          .id(durationID)
        Spacer(minLength: 0.0)
        SubtitleCell(title: "Severity", subtitle: headache.severityDescription)
      }
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: disappeared)
  }
}

extension HeadacheCell {
  
  /// Updates the duration view's identifier.
  func updateDurationID() {
    DispatchQueue.main.async {
      withAnimation { durationID = UUID() }
    }
  }
  
  /// Called when the view appears.
  func appeared() {
    if previousSeverityRange == nil {
      previousSeverityRange = headache.severityRange
    }
    else if let previousSeverityRange = previousSeverityRange, previousSeverityRange != headache.severityRange {
      self.previousSeverityRange = headache.severityRange
      
      withAnimation {
        severityID = UUID()
      }
    }
    
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

struct HeadacheCell_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheCell(headache: Previewing.CoreData.headache)
      .previewLayout(.fixed(width: 350.0, height: 75.0))
  }
}
