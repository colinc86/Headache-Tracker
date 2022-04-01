//
//  DurationCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct DurationCard: View {
  
  /// The headache to display.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// The waiter to periodically update the view.
  private let durationUpdateWaiter = Waiter()
  
  /// The caption to display.
  private var caption: String? {
    if headache.resolved, let endTime = headache.endTime {
      return "until " + endTime.formattedNonRelative()
    }
    return nil
  }
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Duration",
      systemImage: "timer",
      foregroundColor: colorTheme.green
    ) {
      Text(Formatters.formatInterval(headache.duration))
        .font(.title)
        .id(durationID)
    } caption: {
      if let caption = caption {
        Text(caption)
      }
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: durationUpdateWaiter.stop)
  }
  
}

extension DurationCard {
  
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
      durationUpdateWaiter.wait(for: 60.0, repeats: true, completion: updateDurationID)
    }
  }
  
}

struct DurationCard_Previews: PreviewProvider {
  static var previews: some View {
    DurationCard(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
