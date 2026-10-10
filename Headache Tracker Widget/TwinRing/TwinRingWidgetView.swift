//
//  TwinRingWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The twin-ring widget's family switch.
struct TwinRingWidgetView: View {

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

  var body: some View {
    Group {
      switch family {
      case .accessoryCircular:
        circular
      case .accessoryInline:
        inline
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
        glyph(outerWidth: 11, innerWidth: 8, gap: 4, percentSize: 30, showsLabel: true)
          .frame(width: 112, height: 112)
          .riskWidgetStale(snapshot.isStale)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottomTrailing) {
      if snapshot.activeHeadache == nil, !snapshot.isEmpty {
        RiskAgeDot(snapshot: snapshot, freshTint: colorTheme.green, staleTint: colorTheme.orange)
          .padding(Tokens.Spacing.xs)
      }
    }
  }

  // MARK: Circular

  private var circular: some View {
    ZStack {
      AccessoryWidgetBackground()
      switch RiskWidgetState(snapshot) {
      case .empty:
        Image(systemName: "sparkles")
          .font(.system(size: 16, weight: .semibold))
      case .activeHeadache(let headache):
        ZStack {
          Circle()
            .stroke(Color.primary.opacity(0.5), lineWidth: 6)
            .padding(3)
          VStack(spacing: 0) {
            Image(systemName: "brain.head.profile")
              .font(.system(size: 14, weight: .semibold))
            if let start = headache.start {
              Text(RiskFormat.elapsed(since: start, relativeTo: entry.date))
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
          }
          .widgetAccentable()
        }
        .privacySensitive()
      case .forecast, .stale:
        glyph(outerWidth: 6, innerWidth: 4, gap: 3, percentSize: 15, showsLabel: false)
          .padding(2)
      }
    }
  }

  // MARK: Inline

  private var inline: some View {
    Group {
      switch RiskWidgetState(snapshot) {
      case .empty:
        Text("No forecast yet")
      case .activeHeadache(let headache):
        if let start = headache.start {
          Text("\(Image(systemName: "brain.head.profile")) \(headache.severity.title) headache · \(RiskFormat.elapsed(since: start, relativeTo: entry.date))")
        }
        else {
          Text("\(Image(systemName: "brain.head.profile")) \(headache.severity.title) headache")
        }
      case .forecast, .stale:
        if let probability = snapshot.probability24 {
          let suffix = snapshot.isStale ? " · stale" : ""
          let range = snapshot.interval24.map({ " (\(RiskFormat.range($0).dropLast()))" }) ?? ""
          if let short = snapshot.probability12 {
            Text("\(Image(systemName: "brain.head.profile")) Risk \(RiskFormat.percent(probability))\(range) · 12h \(RiskFormat.percent(short))\(suffix)")
          }
          else if let tier = snapshot.tier24 {
            Text("\(Image(systemName: "brain.head.profile")) Risk \(RiskFormat.percent(probability)) · \(RiskFormat.shortTier(tier))\(suffix)")
          }
        }
      }
    }
    .privacySensitive()
  }

  // MARK: Glyph

  private func glyph(outerWidth: CGFloat, innerWidth: CGFloat, gap: CGFloat, percentSize: CGFloat, showsLabel: Bool) -> some View {
    RiskRingGauge(
      probability: snapshot.probability24 ?? 0.0,
      tint: tint24,
      lineWidth: outerWidth,
      inner: snapshot.probability12.map({ RiskRingInner(probability: $0, tint: tint12, lineWidth: innerWidth) }),
      band: snapshot.interval24,
      gap: gap
    ) {
      VStack(spacing: showsLabel ? 1 : 0) {
        Text(RiskFormat.percent(snapshot.probability24 ?? 0.0))
          .font(.system(size: percentSize, weight: .bold, design: .rounded).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        if showsLabel {
          if snapshot.probability12 != nil {
            HStack(spacing: 3) {
              Circle()
                .fill(renderingMode == .fullColor ? tint12 : Color.primary.opacity(0.45))
                .frame(width: 3, height: 3)
              Text("12h")
                .foregroundStyle(renderingMode == .fullColor ? tint12 : .secondary)
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
          }
          else if let tier = snapshot.tier24 {
            Text(RiskFormat.shortTier(tier))
              .font(.system(size: 9, weight: .semibold, design: .rounded))
              .foregroundStyle(renderingMode == .fullColor ? tint24 : .secondary)
          }
        }
      }
      .privacySensitive()
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
    case .forecast, .stale:
      var parts = [String]()
      if let probability = snapshot.probability24 {
        parts.append("\(RiskFormat.spokenPercent(probability)) risk in the next 24 hours")
      }
      if let short = snapshot.probability12 {
        parts.append("\(RiskFormat.spokenPercent(short)) in the next 12")
      }
      if let tier = snapshot.tier24 {
        parts.append(RiskFormat.shortTier(tier))
      }
      if let interval = snapshot.interval24 {
        parts.append(RiskFormat.spokenRangeSentence(interval))
      }
      if let age = snapshot.age {
        parts.append(snapshot.isStale ? "Stale, open to refresh" : "Updated \(RiskFormat.spokenAge(age))")
      }
      return parts.joined(separator: ". ") + "."
    }
  }

}
