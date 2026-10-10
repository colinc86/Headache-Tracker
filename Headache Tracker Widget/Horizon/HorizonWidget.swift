//
//  HorizonWidget.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// A weather-forecast-style strip: the last 48 hours of logged forecasts
/// flowing into two forecast bars for the next 12 and 24 hours, with the
/// trajectory and where in the day the risk sits.
struct HorizonWidget: Widget {

  let kind: String = Constants.Widgets.horizonWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
      HorizonWidgetView(entry: entry)
        .riskWidgetChrome(.dense)
        .widgetURL(Constants.URLSchemes.url(host: Constants.URLSchemes.outlookHost))
    }
    .configurationDisplayName("Risk Horizon")
    .description("Where your risk has been over the last two days and where it's heading in the next 12 and 24 hours.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }

}

#Preview("Medium", as: .systemMedium) {
  HorizonWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.low())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}

#Preview("Large", as: .systemLarge) {
  HorizonWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
}
