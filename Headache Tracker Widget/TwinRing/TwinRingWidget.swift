//
//  TwinRingWidget.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// Two concentric rings: the inner one is the next 12 hours, the outer one
/// the next 24, each tinted by its own tier. The glanceable widget, with
/// Lock Screen and StandBy forms.
struct TwinRingWidget: Widget {

  let kind: String = Constants.Widgets.twinRingWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
      TwinRingWidgetView(entry: entry)
        .riskWidgetChrome(.hero)
        .widgetURL(Constants.URLSchemes.url(host: Constants.URLSchemes.outlookHost))
    }
    .configurationDisplayName("Risk Rings")
    .description("Your 12- and 24-hour headache risk as two rings.")
    .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
  }

}

#Preview("Small", as: .systemSmall) {
  TwinRingWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.low())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}

#Preview("Circular", as: .accessoryCircular) {
  TwinRingWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}

#Preview("Inline", as: .accessoryInline) {
  TwinRingWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
}
