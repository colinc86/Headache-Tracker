//
//  OutlookWidget.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import ApplicationKey
import WidgetKit
import SwiftUI

struct OutlookWidget: Widget {
  let kind: String = Constants.Widgets.outlookWidgetKind
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: OutlookWidgetProvider()) { entry in
      OutlookView(outlook: HolisticOutlook(
        outlook: entry.outlook ?? .noHeadache,
        onset: entry.onset ?? Date(timeIntervalSinceNow: 86400.0),
        duration: entry.duration ?? 0.0,
        severity: entry.severity ?? .notPresent))
        .padding()
    }
    .configurationDisplayName("Daily Outlook")
    .description("A daily headache outlook widget.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
