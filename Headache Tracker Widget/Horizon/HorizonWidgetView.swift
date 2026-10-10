//
//  HorizonWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The horizon widget's family switch.
struct HorizonWidgetView: View {

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

  private var isLarge: Bool {
    return family == .systemLarge
  }

  var body: some View {
    Group {
      switch RiskWidgetState(snapshot) {
      case .empty:
        RiskEmptyStateView()
      default:
        content
      }
    }
    .riskWidgetPlaceholder(snapshot.isPlaceholder)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  // MARK: Content

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      header

      HStack(alignment: .bottom, spacing: Tokens.Spacing.md) {
        historyPane
          .frame(maxWidth: .infinity)
          .layoutPriority(1)

        if let headache = snapshot.activeHeadache {
          ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity), compact: true, showsHint: false)
            .frame(width: 124, alignment: .leading)
        }
        else {
          HorizonBars(snapshot: snapshot, tint12: tint12, tint24: tint24, trackHeight: isLarge ? 72 : 44)
            .riskWidgetStale(snapshot.isStale)
        }
      }

      footer

      if isLarge {
        WidgetHairline()
          .padding(.vertical, Tokens.Spacing.xs)
        reasons
        Spacer(minLength: 0)
        HStack {
          Spacer()
          RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
        }
      }
    }
  }

  private var header: some View {
    HStack {
      Text("Risk horizon")
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(.secondary)
      Spacer()
      if !isLarge {
        RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
          .padding(.trailing, Tokens.Spacing.xs)
      }
      if snapshot.activeHeadache != nil {
        Text("In progress")
          .font(.system(.caption2, design: .rounded).weight(.semibold))
          .foregroundStyle(.secondary)
      }
      else {
        TrajectoryGlyph(trajectory: snapshot.trajectory, tint: tint24)
      }
    }
  }

  private var historyPane: some View {
    VStack(alignment: .leading, spacing: 2) {
      if snapshot.history.count >= 2 {
        RiskSparklineStatic(values: snapshot.history.map({ $0.probability }), color: tint24, lineWidth: 2.5, endDotSize: 7)
          .frame(height: isLarge ? 96 : 58)
          .privacySensitive()
      }
      else {
        Text("History builds as forecasts run")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: isLarge ? 96 : 58, maxHeight: isLarge ? 96 : 58)
      }
      HStack {
        Text("48h ago")
        Spacer()
        Text("now")
      }
      .font(.system(size: 8, weight: .medium, design: .rounded))
      .foregroundStyle(.secondary)
    }
  }

  private var footer: some View {
    Group {
      if snapshot.activeHeadache != nil {
        Text("Headache logged · forecasts resume after")
      }
      else {
        Text(snapshot.peakWindowText)
          .privacySensitive()
      }
    }
    .font(.system(.caption2, design: .rounded).weight(.medium))
    .lineLimit(2)
    .minimumScaleFactor(0.85)
    .fixedSize(horizontal: false, vertical: true)
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
      return "No forecast yet."
    case .activeHeadache(let headache):
      if let start = headache.start {
        return "\(headache.severity.title) headache, for \(RiskFormat.elapsed(since: start, relativeTo: entry.date))."
      }
      return "\(headache.severity.title) headache."
    default:
      var parts = [String]()
      if let trajectory = snapshot.trajectory {
        parts.append("Risk \(trajectory.title.lowercased())")
      }
      if let short = snapshot.probability12 {
        parts.append("\(RiskFormat.spokenPercent(short)) in the next 12 hours")
      }
      if let probability = snapshot.probability24 {
        parts.append("\(RiskFormat.spokenPercent(probability)) in the next 24")
      }
      if let interval = snapshot.interval24 {
        parts.append(RiskFormat.spokenRangeSentence(interval))
      }
      parts.append(snapshot.peakWindowText)
      if snapshot.history.count >= 2 {
        parts.append("History: " + RiskSparklineStatic(values: snapshot.history.map({ $0.probability }), color: .clear).accessibilityDescription)
      }
      return parts.joined(separator: ". ") + "."
    }
  }

}

/// The two forecast bars ("+12h", "+24h").
struct HorizonBars: View {

  /// The snapshot.
  let snapshot: RiskSnapshot

  /// The 12-hour tint.
  let tint12: Color

  /// The 24-hour tint.
  let tint24: Color

  /// The bar track's height.
  var trackHeight: CGFloat = 44

  @Environment(\.widgetRenderingMode) private var renderingMode

  var body: some View {
    HStack(alignment: .bottom, spacing: Tokens.Spacing.md) {
      if let short = snapshot.probability12 {
        bar(title: "+12h", probability: short, tint: tint12, width: 26, accentable: false)
      }
      if let probability = snapshot.probability24 {
        bar(title: "+24h", probability: probability, tint: tint24, width: snapshot.probability12 == nil ? 34 : 26, accentable: true, band: snapshot.interval24)
      }
    }
    .privacySensitive()
  }

  private func bar(title: String, probability: Double, tint: Color, width: CGFloat, accentable: Bool, band: RiskInterval? = nil) -> some View {
    let fill: Color = renderingMode == .fullColor ? tint : (accentable ? .primary : Color.primary.opacity(0.3))
    return VStack(spacing: 3) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(RiskFormat.percent(probability))
        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
        .foregroundStyle(renderingMode == .fullColor ? tint : .primary)
        .widgetAccentable(accentable)
      ZStack(alignment: .bottom) {
        RoundedRectangle(cornerRadius: Tokens.Radius.sm)
          .fill(fill.opacity(0.15))
        RoundedRectangle(cornerRadius: Tokens.Radius.sm)
          .fill(fill)
          .frame(height: max(4.0, trackHeight * CGFloat(min(max(probability, 0.0), 1.0))))
          .widgetAccentable(accentable)
        if let band = band {
          // The range as a whisker up the bar's centre line: a stem from the
          // lower to the upper bound with short caps.
          let lower = trackHeight * CGFloat(min(max(band.lower, 0.0), 1.0))
          let upper = trackHeight * CGFloat(min(max(band.upper, 0.0), 1.0))
          let whisker: Color = renderingMode == .fullColor ? Color.white.opacity(0.85) : Color.primary.opacity(0.6)
          VStack(spacing: 0) {
            Capsule().fill(whisker).frame(width: 6, height: 1.5)
            Rectangle().fill(whisker).frame(width: 1.5, height: max(upper - lower - 3.0, 0.0))
            Capsule().fill(whisker).frame(width: 6, height: 1.5)
          }
          .padding(.bottom, lower)
        }
      }
      .frame(width: width, height: trackHeight)
    }
  }

}
