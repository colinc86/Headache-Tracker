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
  let kind: String = Constants.Widgets.severityWidgetKind
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SeverityWidgetProvider()) { entry in
      SeveritySelectionView(currentSeverity: entry.severity, mode: .widget)
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
    .configurationDisplayName("Track Headache")
    .description("Track your current headache.")
    .supportedFamilies([.systemMedium])
    .contentMarginsDisabled()
  }
}
