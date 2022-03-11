//
//  OutlookWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/6/22.
//

import SwiftUI

struct OutlookWidgetView: View {
  
  /// The view's entry.
  let entry: OutlookWidgetContent
  
  // MARK: View body
  
  var body: some View {
    if entry.hasCurrentHeadache {
      DurationPredictionView(duration: entry.duration ?? 0.0, date: entry.date)
        .padding()
    }
    else {
      OutlookView(outlook: HolisticOutlook(
        outlook: entry.outlook ?? .noHeadache,
        onset: entry.onset ?? Date(timeIntervalSinceNow: 86400.0),
        duration: entry.duration ?? 0.0,
        severity: entry.severity ?? .notPresent))
        .padding()
    }
  }
}

struct OutlookWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookWidgetView(entry: OutlookWidgetProvider.placeholder)
  }
}
