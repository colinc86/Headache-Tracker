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
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  private let durationUpdateWaiter = Waiter()
  
  private var caption: String? {
    if headache.resolved, let endTime = headache.endTime {
      return "until " + endTime.formattedNonRelative()
    }
    return nil
  }
  
  var body: some View {
    TitleCaptionView(title: "Duration", systemImage: "timer", foregroundColor: colorScheme.themeColor(for: .green), caption: caption) {
      VStack(alignment: .leading) {
        Text(Formatters.formatInterval(headache.duration))
          .font(.title)
          .id(durationID)
      }
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: durationUpdateWaiter.stop)
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
      durationUpdateWaiter.wait(for: 60.0, repeats: true, completion: updateDurationID)
    }
  }
  
}

struct DurationView_Previews: PreviewProvider {
  static var previews: some View {
    DurationView(headache: Previewing.CoreData.resolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
