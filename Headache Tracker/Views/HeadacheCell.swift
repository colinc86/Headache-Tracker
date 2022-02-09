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
  
  // MARK: View body
  
  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "brain.head.profile")
        .foregroundColor(headache.resolved ? .secondary : .accentColor)
      
      SeverityLevel(headache: headache)
        .id(severityID)
      
      VStack {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formatted() ?? "N/A")
        SubtitleCell(title: "Duration", subtitle: Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "0 min")
          .id(durationID)
        
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
    withAnimation {
      severityID = UUID()
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
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
}
