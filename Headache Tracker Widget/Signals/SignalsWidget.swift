//
//  SignalsWidget.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// What's driving the forecast right now: the per-signal contributions split
/// into what's raising risk and what's in the user's favor, with a domain
/// fingerprint in the large family.
struct SignalsWidget: Widget {

  let kind: String = Constants.Widgets.signalsWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
      SignalsWidgetView(entry: entry)
        .riskWidgetChrome(.dense)
        .widgetURL(Constants.URLSchemes.url(host: Constants.URLSchemes.signalsHost))
    }
    .configurationDisplayName("Risk Signals")
    .description("What's pushing your headache risk up right now, and what's working in your favor.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }

}

#Preview("Medium", as: .systemMedium) {
  SignalsWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}

#Preview("Large", as: .systemLarge) {
  SignalsWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
}
