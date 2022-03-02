//
//  SeverityWidget.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import ApplicationKey
import WidgetKit
import SwiftUI

struct SeverityWidget: Widget {
  let kind: String = ApplicationKey(from: "severity")
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SeverityWidgetProvider()) { entry in
      SeverityWidgetView(entry: entry)
    }
    .configurationDisplayName("Track Headache")
    .description("Track your current headache.")
    .supportedFamilies([.systemMedium])
  }
}
