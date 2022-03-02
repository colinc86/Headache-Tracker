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
  let kind: String = SharedConstants.Widgets.outlookWidgetKind
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: OutlookWidgetProvider()) { entry in
      OutlookWidgetView(entry: entry)
    }
    .configurationDisplayName("Daily Outlook")
    .description("A daily headache outlook widget.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
