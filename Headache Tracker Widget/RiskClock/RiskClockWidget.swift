//
//  RiskClockWidget.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// A 24-hour dial: the half-turn from now is the 12-hour window, the rest is
/// the following 12, each shaded by its tier. Reads like "when", not just
/// "how much".
struct RiskClockWidget: Widget {

  let kind: String = Constants.Widgets.riskClockWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
      RiskClockWidgetView(entry: entry)
        .riskWidgetChrome(.dense)
        .widgetURL(Constants.URLSchemes.url(host: Constants.URLSchemes.outlookHost))
    }
    .configurationDisplayName("Risk Clock")
    .description("The next 24 hours as a dial: the first half-turn is the next 12, shaded by how likely a headache is.")
    .supportedFamilies([.systemMedium])
  }

}

#Preview("Medium", as: .systemMedium) {
  RiskClockWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.low())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}
