//
//  OutlookWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/6/22.
//

import SwiftUI
import WidgetKit

/// The outlook widget: the hero ring with the 24-hour risk, the 12-hour chip,
/// what's driving it (medium), and the recent history plus reasons (large).
struct OutlookWidgetView: View {

  /// The entry.
  let entry: RiskWidgetEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var snapshot: RiskSnapshot {
    return entry.snapshot
  }

  private var tint24: Color {
    return snapshot.tier24.map({ colorTheme.color(for: $0) }) ?? .secondary
  }

  private var tint12: Color {
    return snapshot.tier12.map({ colorTheme.color(for: $0) }) ?? .secondary
  }

  private var maxMagnitude: Double {
    return snapshot.signals.compactMap({ $0.delta }).map(abs).max() ?? 0.0
  }

  var body: some View {
    Group {
      switch family {
      case .systemMedium:
        medium
      case .systemLarge:
        large
      default:
        small
      }
    }
    .riskWidgetPlaceholder(snapshot.isPlaceholder)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  // MARK: Small

  private var small: some View {
    ZStack {
      switch RiskWidgetState(snapshot) {
      case .empty:
        RiskEmptyStateView(compact: true)
      case .activeHeadache(let headache):
        ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity), compact: true)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      case .forecast, .stale:
        VStack(spacing: Tokens.Spacing.xs) {
          ring(size: 92, lineWidth: 9, innerWidth: 5, percentSize: 26, showsTier: true)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .riskWidgetStale(snapshot.isStale)
      }
    }
    .overlay(alignment: .topTrailing) {
      if snapshot.activeHeadache == nil, let short = snapshot.probability12 {
        HorizonChip(probability: short, tint: tint12)
      }
    }
    .overlay(alignment: .bottomLeading) {
      if snapshot.activeHeadache == nil {
        RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
      }
    }
  }

  // MARK: Medium

  private var medium: some View {
    HStack(spacing: Tokens.Spacing.lg) {
      switch RiskWidgetState(snapshot) {
      case .empty:
        RiskEmptyStateView()
      case .activeHeadache(let headache):
        ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity))
          .frame(width: 120, alignment: .leading)
        rows
      case .forecast, .stale:
        ring(size: 96, lineWidth: 9, innerWidth: 4, percentSize: 26, showsTier: false)
          .riskWidgetStale(snapshot.isStale)
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
          if let tier = snapshot.tier24 {
            Text(tier.title)
              .font(.system(.headline, design: .rounded))
              .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
              .privacySensitive()
          }
          HStack {
            if let short = snapshot.probability12 {
              HorizonChip(probability: short, tint: tint12)
            }
            Spacer()
            RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
          }
          rangeRow
          WidgetHairline()
          rows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  // MARK: Large

  private var large: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
      switch RiskWidgetState(snapshot) {
      case .empty:
        RiskEmptyStateView()
      case .activeHeadache(let headache):
        HStack(alignment: .top, spacing: Tokens.Spacing.lg) {
          ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity))
            .frame(width: 130, alignment: .leading)
          rows
        }
        WidgetHairline()
        reasons
        Spacer(minLength: 0)
      case .forecast, .stale:
        HStack(spacing: Tokens.Spacing.lg) {
          ring(size: 110, lineWidth: 10, innerWidth: 5, percentSize: 30, showsTier: false)
            .riskWidgetStale(snapshot.isStale)
          VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            if let tier = snapshot.tier24 {
              Text(tier.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .privacySensitive()
            }
            HStack {
              if let short = snapshot.probability12 {
                HorizonChip(probability: short, tint: tint12)
              }
              Spacer()
              RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
            }
            rangeRow
            WidgetHairline()
            rows
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("Last 48 hours")
          .font(.system(.caption, design: .rounded).weight(.semibold))
          .foregroundStyle(.secondary)
        if snapshot.history.count >= 2 {
          RiskSparklineStatic(values: snapshot.history.map({ $0.probability }), color: tint24)
            .frame(height: 64)
            .privacySensitive()
        }
        else {
          Text("History builds as forecasts run")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
        }

        WidgetHairline()
        reasons
        Spacer(minLength: 0)
      }
    }
  }

  // MARK: Pieces

  /// The range and the confidence badge, when the forecast carries either.
  @ViewBuilder private var rangeRow: some View {
    if snapshot.interval24 != nil || snapshot.coverage != nil {
      HStack(spacing: Tokens.Spacing.xs) {
        let parts = [snapshot.interval24.map({ "Likely \(RiskFormat.range($0))" }), snapshot.accuracy?.text].compactMap({ $0 })
        if !parts.isEmpty {
          Text(parts.joined(separator: " · "))
            .font(.system(.caption2, design: .rounded).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        ForecastConfidenceBadge(confidence: snapshot.confidence, monochrome: renderingMode != .fullColor)
      }
      .privacySensitive()
    }
  }

  private func ring(size: CGFloat, lineWidth: CGFloat, innerWidth: CGFloat, percentSize: CGFloat, showsTier: Bool) -> some View {
    RiskRingGauge(
      probability: snapshot.probability24 ?? 0.0,
      tint: tint24,
      lineWidth: lineWidth,
      inner: snapshot.probability12.map({ RiskRingInner(probability: $0, tint: tint12, lineWidth: innerWidth) }),
      band: snapshot.interval24,
      gap: 6,
      trackOpacity: 0.18
    ) {
      VStack(spacing: 0) {
        Text(RiskFormat.percent(snapshot.probability24 ?? 0.0))
          .font(.system(size: percentSize, weight: .bold, design: .rounded).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        if showsTier, let tier = snapshot.tier24 {
          Text(RiskFormat.shortTier(tier))
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(renderingMode == .fullColor ? tint24 : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
      .privacySensitive()
    }
    .frame(width: size, height: size)
  }

  private var rows: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      let signals = Array(snapshot.signals.prefix(3))
      if signals.isEmpty {
        Text("Reasons appear after your next refresh.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      else {
        ForEach(signals) { signal in
          ContributionRow(
            signal: signal,
            maxMagnitude: maxMagnitude,
            raisingTint: tint24,
            easingTint: colorTheme.color(for: .low),
            iconTint: colorTheme.baseColor)
          .privacySensitive()
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var reasons: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      Text("Why")
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(.secondary)
      if let brief = snapshot.brief, !brief.reasons.isEmpty {
        ForEach(brief.reasons.prefix(3), id: \.self) { reason in
          Label {
            Text(reason)
              .font(.system(.footnote, design: .rounded))
              .lineLimit(2)
              .minimumScaleFactor(0.85)
              .fixedSize(horizontal: false, vertical: true)
          } icon: {
            Image(systemName: "arrow.up.right.circle")
              .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
          }
        }
        .privacySensitive()
      }
      else {
        Text("Nothing unusual vs. your baselines.")
          .font(.system(.footnote, design: .rounded))
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: Accessibility

  private var accessibilityText: String {
    switch RiskWidgetState(snapshot) {
    case .empty:
      return "No forecast yet. Log a few days to train your model."
    case .activeHeadache(let headache):
      if let start = headache.start {
        return "\(headache.severity.title) headache, for \(RiskFormat.elapsed(since: start, relativeTo: entry.date))."
      }
      return "\(headache.severity.title) headache."
    case .forecast, .stale:
      var parts = [String]()
      if let tier = snapshot.tier24 {
        parts.append("\(tier.title)")
      }
      if let probability = snapshot.probability24 {
        parts.append("\(RiskFormat.spokenPercent(probability)) chance of a headache in the next 24 hours")
      }
      if let short = snapshot.probability12 {
        parts.append("\(RiskFormat.spokenPercent(short)) in the next 12")
      }
      if let interval = snapshot.interval24 {
        parts.append(RiskFormat.spokenRangeSentence(interval))
      }
      if let accuracy = snapshot.accuracy {
        parts.append("The model has been \(accuracy.spokenText)")
      }
      if snapshot.interval24 != nil || snapshot.coverage != nil {
        parts.append("Confidence \(snapshot.confidence.title.lowercased())")
      }
      if let age = snapshot.age {
        parts.append(snapshot.isStale ? "Stale, open to refresh" : "Updated \(RiskFormat.spokenAge(age))")
      }
      return parts.joined(separator: ". ") + "."
    }
  }

}

#Preview("Small", as: .systemSmall) {
  OutlookWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.low())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.empty())
}

#Preview("Medium", as: .systemMedium) {
  OutlookWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.stale())
}

#Preview("Large", as: .systemLarge) {
  OutlookWidget()
} timeline: {
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.elevated())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.high())
  RiskWidgetEntry(date: .now, snapshot: RiskSnapshot.Samples.activeHeadache())
}
