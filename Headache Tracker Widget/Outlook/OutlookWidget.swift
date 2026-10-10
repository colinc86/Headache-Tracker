//
//  OutlookWidget.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import SwiftUI
import WidgetKit

/// The daily outlook: the 24-hour risk as a ring, the 12-hour horizon, and
/// what's driving it.
struct OutlookWidget: Widget {

  let kind: String = Constants.Widgets.outlookWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
      OutlookWidgetView(entry: entry)
        .riskWidgetChrome(.hero)
        .widgetURL(Constants.URLSchemes.url(host: Constants.URLSchemes.outlookHost))
    }
    .configurationDisplayName("Daily Outlook")
    .description("Your headache risk for the next 12 and 24 hours, and what's driving it.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }

}
