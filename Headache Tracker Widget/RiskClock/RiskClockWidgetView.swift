//
//  RiskClockWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The risk clock: a dial on the left, a legend on the right.
struct RiskClockWidgetView: View {

  /// The entry.
  let entry: RiskWidgetEntry

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
    HStack(spacing: Tokens.Spacing.lg) {
      RiskClockDial(snapshot: snapshot, now: entry.date, tint12: tint12, tint24: tint24, severityTint: snapshot.activeHeadache.map({ colorTheme.color(for: $0.severity) }))
        .frame(width: 128, height: 128)
        .riskWidgetStale(snapshot.isStale)

      legend
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .riskWidgetPlaceholder(snapshot.isPlaceholder)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  // MARK: Legend

  private var legend: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
      switch RiskWidgetState(snapshot) {
      case .empty:
        Text("No forecast yet")
          .font(.system(.subheadline, design: .rounded).weight(.semibold))
        Text("Log a few days to train your model")
          .font(.caption2)
          .foregroundStyle(.secondary)
      case .activeHeadache(let headache):
        ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity), compact: true, showsHint: false)
        if let start = headache.start {
          Text("Started \(start.formatted(date: .omitted, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .privacySensitive()
        }
        Text("Tap to update")
          .font(.caption2)
          .foregroundStyle(.secondary)
      case .forecast, .stale:
        if let short = snapshot.probability12, let tier = snapshot.tier12 {
          legendRow(dotTint: tint12, filled: false, title: "Next 12h", value: "\(RiskFormat.shortTier(tier)) · \(RiskFormat.percent(short))")
        }
        if let probability = snapshot.probability24, let tier = snapshot.tier24 {
          legendRow(dotTint: tint24, filled: true, title: "Next 24h", value: "\(RiskFormat.shortTier(tier)) · \(RiskFormat.percent(probability))")
        }
        if snapshot.probability12 == nil {
          Text("12h forecast trains with more data")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
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
        HStack(spacing: Tokens.Spacing.xs) {
          TrajectoryGlyph(trajectory: snapshot.trajectory, tint: tint24, showsTitle: false)
          Text(snapshot.peakWindowText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
        }
        .privacySensitive()
        RiskAgeLabel(snapshot: snapshot, staleTint: colorTheme.orange)
      }
    }
  }

  private func legendRow(dotTint: Color, filled: Bool, title: String, value: String) -> some View {
    HStack(spacing: 6) {
      Group {
        if filled || renderingMode == .fullColor {
          Circle().fill(renderingMode == .fullColor ? dotTint : Color.primary)
        }
        else {
          Circle().stroke(Color.primary, lineWidth: 1.5)
        }
      }
      .frame(width: 8, height: 8)
      .widgetAccentable(filled)
      Text(title)
        .font(.system(.caption, design: .rounded))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .privacySensitive()
  }

  // MARK: Accessibility

  private var accessibilityText: String {
    switch RiskWidgetState(snapshot) {
    case .empty:
      return "Risk clock. No forecast yet."
    case .activeHeadache(let headache):
      if let start = headache.start {
        return "Risk clock. \(headache.severity.title) headache, for \(RiskFormat.elapsed(since: start, relativeTo: entry.date))."
      }
      return "Risk clock. \(headache.severity.title) headache."
    default:
      var parts = ["Risk clock"]
      let nowLabel = RiskFormat.hourLabel(entry.date)
      if let short = snapshot.probability12, let tier = snapshot.tier12 {
        parts.append("Next 12 hours from \(nowLabel): \(RiskFormat.shortTier(tier).lowercased()), \(RiskFormat.spokenPercent(short))")
      }
      if let probability = snapshot.probability24, let tier = snapshot.tier24 {
        parts.append("Next 24 hours: \(RiskFormat.shortTier(tier).lowercased()), \(RiskFormat.spokenPercent(probability))")
      }
      if let interval = snapshot.interval24 {
        parts.append(RiskFormat.spokenRangeSentence(interval))
      }
      if let accuracy = snapshot.accuracy {
        parts.append("The model has been \(accuracy.spokenText)")
      }
      parts.append(snapshot.peakWindowText)
      if let age = snapshot.age {
        parts.append(snapshot.isStale ? "Stale, open to refresh" : "Updated \(RiskFormat.spokenAge(age))")
      }
      return parts.joined(separator: ". ") + "."
    }
  }

}

/// The 24-hour dial.
struct RiskClockDial: View {

  /// The snapshot.
  let snapshot: RiskSnapshot

  /// The moment at 12 o'clock.
  let now: Date

  /// The 12-hour tint.
  let tint12: Color

  /// The 24-hour tint.
  let tint24: Color

  /// The severity tint during an active headache.
  let severityTint: Color?

  @Environment(\.widgetRenderingMode) private var renderingMode

  private let lineWidth: CGFloat = 12
  private let gapDegrees = 3.0

  private func opacity(for probability: Double) -> Double {
    return 0.35 + 0.65 * min(max(probability, 0.0), 1.0)
  }

  var body: some View {
    GeometryReader { geometry in
      // Leave room inside the frame for the ticks and the hour labels, so
      // nothing is clipped at the widget's edge or runs into the legend.
      let size = min(geometry.size.width, geometry.size.height)
      let center = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
      let outerRadius = size / 2.0 - 20.0
      let ringRadius = outerRadius - lineWidth / 2.0

      ZStack {
        // Track.
        Circle()
          .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
          .frame(width: ringRadius * 2.0, height: ringRadius * 2.0)

        arcs(ringRadius: ringRadius)

        // Hour ticks and labels.
        ForEach(0 ..< 4, id: \.self) { index in
          let angle = Angle.degrees(Double(index) * 90.0 - 90.0)
          let tickRadius = outerRadius + 5.0
          let labelRadius = outerRadius + 16.0
          RoundedRectangle(cornerRadius: 1)
            .fill(.secondary)
            .frame(width: 2, height: 6)
            .rotationEffect(angle + .degrees(90.0))
            .position(x: center.x + tickRadius * cos(angle.radians), y: center.y + tickRadius * sin(angle.radians))
          Text(RiskFormat.hourLabel(now.addingTimeInterval(Double(index) * 6.0 * 3600.0)))
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(renderingMode == .fullColor ? .secondary : Color.primary.opacity(0.6))
            .position(x: center.x + labelRadius * cos(angle.radians), y: center.y + labelRadius * sin(angle.radians))
        }

        // The "now" marker.
        Circle()
          .fill(.primary)
          .frame(width: 7, height: 7)
          .overlay(Circle().stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 1.5))
          .position(x: center.x, y: center.y - ringRadius)
          .widgetAccentable()

        centerContent(ringRadius: ringRadius, center: center)
      }
    }
  }

  @ViewBuilder
  private func arcs(ringRadius: CGFloat) -> some View {
    if let severityTint = severityTint {
      Circle()
        .stroke((renderingMode == .fullColor ? severityTint : Color.primary).opacity(0.5), lineWidth: lineWidth)
        .frame(width: ringRadius * 2.0, height: ringRadius * 2.0)
        .widgetAccentable()
    }
    else if let probability = snapshot.probability24 {
      if let short = snapshot.probability12 {
        ClockArc(from: gapDegrees, to: 180.0 - gapDegrees)
          .stroke((renderingMode == .fullColor ? tint12 : Color.primary.opacity(0.45)).opacity(opacity(for: short)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
          .frame(width: ringRadius * 2.0, height: ringRadius * 2.0)
        ClockArc(from: 180.0 + gapDegrees, to: 360.0 - gapDegrees)
          .stroke((renderingMode == .fullColor ? tint24 : Color.primary).opacity(opacity(for: probability)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
          .frame(width: ringRadius * 2.0, height: ringRadius * 2.0)
          .widgetAccentable()
      }
      else {
        ClockArc(from: gapDegrees + 1.0, to: 360.0 - gapDegrees - 1.0)
          .stroke((renderingMode == .fullColor ? tint24 : Color.primary).opacity(opacity(for: probability)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
          .frame(width: ringRadius * 2.0, height: ringRadius * 2.0)
          .widgetAccentable()
      }
    }
  }

  @ViewBuilder
  private func centerContent(ringRadius: CGFloat, center: CGPoint) -> some View {
    if let headache = snapshot.activeHeadache {
      if let start = headache.start {
        Text(start, style: .relative)
          .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
          .multilineTextAlignment(.center)
          .frame(width: ringRadius * 1.3)
          .privacySensitive()
      }
    }
    else if let probability = snapshot.probability24 {
      if let short = snapshot.probability12 {
        // Percent callouts at each arc's midpoint, inside the ring.
        let calloutRadius = ringRadius - lineWidth / 2.0 - 12.0
        Text(RiskFormat.percent(short))
          .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(renderingMode == .fullColor ? tint12 : .primary)
          .position(x: center.x + calloutRadius, y: center.y)
          .privacySensitive()
        Text(RiskFormat.percent(probability))
          .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
          .position(x: center.x - calloutRadius, y: center.y)
          .privacySensitive()
          .widgetAccentable()
      }
      else {
        Text(RiskFormat.percent(probability))
          .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
          .privacySensitive()
          .widgetAccentable()
      }
    }
    else {
      Image(systemName: "sparkles")
        .font(.system(size: 18))
        .foregroundStyle(.secondary)
    }
  }

}

/// An arc of a circle inscribed in its frame, in clock degrees (0 at 12
/// o'clock, clockwise).
struct ClockArc: Shape {

  /// The start, in clock degrees.
  let from: Double

  /// The end, in clock degrees.
  let to: Double

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2.0
    var path = Path()
    path.addArc(center: center, radius: radius, startAngle: .degrees(from - 90.0), endAngle: .degrees(to - 90.0), clockwise: false)
    return path
  }

}
