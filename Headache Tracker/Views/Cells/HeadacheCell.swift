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
  @State private var previousSeverityRange: SeverityRange?
  
  private let durationUpdateWaiter = Waiter()
  
  // MARK: View body
  
  var body: some View {
    HStack(alignment: .top) {
      VerticalSeverityLevel(range: headache.severityRange)
        .padding(EdgeInsets(top: 4.0, leading: 0.0, bottom: 4.0, trailing: 0.0))
        .frame(width: 20.0)
        .id(severityID)
      
      VStack {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formattedNonRelative() ?? "N/A")
        Spacer(minLength: 0.0)
        SubtitleCell(
          title: "Duration",
          subtitle: Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "0 min")
          .id(durationID)
        Spacer(minLength: 0.0)
        SubtitleCell(title: "Severity", subtitle: headache.severityRange.description)
      }
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: durationUpdateWaiter.stop)
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
    // Updates the severty view if the range changes
    if previousSeverityRange == nil {
      previousSeverityRange = headache.severityRange
    }
    else if let previousSeverityRange = previousSeverityRange, previousSeverityRange != headache.severityRange {
      self.previousSeverityRange = headache.severityRange
      withAnimation { severityID = UUID() }
    }
    
    // If the headache isn't resolved, then start an update timer
    if !headache.resolved {
      updateDurationID()
      durationUpdateWaiter.wait(for: 60.0, repeats: true, completion: updateDurationID)
    }
  }
  
}

struct HeadacheCell_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheCell(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.fixed(width: 350.0, height: 75.0))
      .previewDisplayName("Resolved Headache")
    
    HeadacheCell(headache: Previewing.CoreData.unresolvedHeadache)
      .previewLayout(.fixed(width: 350.0, height: 75.0))
      .previewDisplayName("Unesolved Headache")
  }
}
