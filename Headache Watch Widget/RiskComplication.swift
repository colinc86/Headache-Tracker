//
//  RiskComplication.swift
//  Headache Watch Widget
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI
import WidgetKit

/// A timeline entry carrying the current forecast (nil when none exists).
struct RiskEntry: TimelineEntry {
  let date: Date
  let probability: Double?
}

/// Reads the forecast from the shared app group. The phone refreshes it on
/// its hourly background task, so the complication re-reads on a similar
/// cadence.
struct RiskProvider: TimelineProvider {

  func placeholder(in context: Context) -> RiskEntry {
    RiskEntry(date: Date(), probability: 0.42)
  }

  func getSnapshot(in context: Context, completion: @escaping (RiskEntry) -> Void) {
    completion(RiskEntry(date: Date(), probability: WatchShared.currentRisk()?.probability))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RiskEntry>) -> Void) {
    let entry = RiskEntry(date: Date(), probability: WatchShared.currentRisk()?.probability)
    let next = Date().addingTimeInterval(60 * 60)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }

}

/// The forecast complication for the Apple Watch face.
struct RiskComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "RiskComplication", provider: RiskProvider()) { entry in
      RiskComplicationView(entry: entry)
    }
    .configurationDisplayName("Headache Risk")
    .description("Your forecasted headache risk for the next 24 hours.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
  }
}

/// Renders the forecast across the supported accessory families.
struct RiskComplicationView: View {

  @Environment(\.widgetFamily) private var family

  let entry: RiskEntry

  private var tier: WatchShared.Tier? {
    entry.probability.map { WatchShared.Tier(probability: $0) }
  }

  var body: some View {
    switch family {
    case .accessoryInline:
      Label(inlineText, systemImage: "brain.head.profile")

    case .accessoryCircular, .accessoryCorner:
      Gauge(value: entry.probability ?? 0) {
        Image(systemName: "brain.head.profile")
      } currentValueLabel: {
        Text(percentShort)
      }
      .gaugeStyle(.accessoryCircular)
      .tint(tier?.color ?? .gray)

    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("Headache Risk", systemImage: "brain.head.profile")
          .font(.headline)
          .foregroundStyle(tier?.color ?? .primary)
        Text(rectangularSubtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

    default:
      Text(percentShort)
    }
  }

  private var inlineText: String {
    guard let probability = entry.probability, let tier = tier else {
      return "No forecast"
    }
    return "\(tier.title) · \(WatchShared.percent(probability))"
  }

  private var percentShort: String {
    guard let probability = entry.probability else { return "—" }
    return "\(Int((probability * 100).rounded()))"
  }

  private var rectangularSubtitle: String {
    guard let probability = entry.probability, let tier = tier else {
      return "Open the app to build your model"
    }
    return "\(tier.title) — \(WatchShared.percent(probability)) in 24h"
  }

}
