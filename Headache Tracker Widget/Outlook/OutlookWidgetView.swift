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
  
  var outlook: HolisticOutlook {
    if entry.hasCurrentHeadache {
      return .headache(severity: entry.severity ?? .notPresent, end: entry.date.addingTimeInterval(entry.duration ?? 0.0))
    }
    return HolisticOutlook(
      outlook: entry.outlook ?? .noHeadache,
      onset: entry.onset ?? Date(timeIntervalSinceNow: 86400.0),
      duration: entry.duration ?? 0.0,
      severity: entry.severity ?? .notPresent)
  }
  
  // MARK: View body
  
  var body: some View {
    OutlookView(outlook: outlook)
      .padding()
  }
}

struct OutlookWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookWidgetView(entry: OutlookWidgetProvider.placeholder)
  }
}
