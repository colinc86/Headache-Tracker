//
//  TrackHeroView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Charts
import SwiftUI

/// The Track tab's forecast hero: the breathing risk orb, the tier, the
/// written summary of what's moving the number, the last two days flowing
/// into the next 24 hours, and the range, accuracy, and confidence. One tap
/// target into Signals.
struct TrackHeroView: View {

  /// The forecast.
  let prediction: RiskPrediction

  /// The headline accuracy.
  let accuracy: ForecastAccuracy?

  /// The logged forecasts over the last two days.
  let history: [HeadacheManager.RiskHistoryPoint]

  /// The written summary.
  let summary: SummaryText?

  /// Whether the model is rewriting the summary.
  let isWriting: Bool

  /// Opens Signals.
  let onOpenSignals: () -> Void

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var tint: Color {
    return colorTheme.color(for: prediction.tier)
  }

  private var percent: Int {
    return Int((prediction.probability * 100.0).rounded())
  }

  var body: some View {
    Button(action: onOpenSignals) {
      VStack(spacing: Tokens.Spacing.md) {
        RiskOrb(percent: percent, tint: tint, diameter: 150)

        VStack(spacing: Tokens.Spacing.xs) {
          Text(prediction.tier.title)
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)
          Text("\(percent)% chance of a headache in the next 24 hours")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }

        if let summary = summary {
          SummaryLine(summary: summary, isWriting: isWriting, alignment: .center)
            .padding(.horizontal, Tokens.Spacing.sm)
        }

        RiskRibbon(
          history: history,
          probability: prediction.probability,
          probability12: prediction.shortProbability.flatMap({ $0 >= 0 ? $0 : nil }),
          interval: prediction.interval,
          now: prediction.computedAt,
          tint: tint)

        HStack(spacing: Tokens.Spacing.sm) {
          let parts = [prediction.interval.map({ "Likely \($0.rangeText)" }), accuracy?.text].compactMap({ $0 })
          if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
              .font(.caption.monospacedDigit())
              .foregroundColor(.secondary)
          }
          if prediction.interval != nil || prediction.coverage != nil {
            ForecastConfidenceBadge(confidence: prediction.confidence)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Tokens.Spacing.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint("Opens Signals")
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("track.hero")
  }

  private var accessibilityText: String {
    var parts = ["\(prediction.tier.title)", "\(percent) percent chance of a headache in the next 24 hours"]
    if let interval = prediction.interval {
      parts.append(interval.spokenText)
    }
    if let summary = summary {
      parts.append(summary.text)
    }
    if let accuracy = accuracy {
      parts.append("The model has been \(accuracy.spokenText)")
    }
    parts.append("Confidence: \(prediction.confidence.title)")
    return parts.joined(separator: ". ") + "."
  }

}

/// A written summary line, with a sparkle mark when Apple Intelligence wrote
/// it and a gentle pulse while it's writing.
struct SummaryLine: View {

  let summary: SummaryText
  let isWriting: Bool
  var alignment: TextAlignment = .leading

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs) {
      if summary.isGenerated || isWriting {
        Image(systemName: "sparkles")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(colorTheme.baseColor)
          .symbolEffect(.pulse, isActive: isWriting)
          .accessibilityHidden(true)
      }
      Text(summary.text)
        .font(.callout)
        .foregroundColor(.primary)
        .multilineTextAlignment(alignment)
        .fixedSize(horizontal: false, vertical: true)
        .contentTransition(.opacity)
    }
  }

}

/// The breathing risk orb: an aura glow around a tinted sphere with the
/// percent counting up. Still under Reduce Motion and UI tests.
struct RiskOrb: View {

  /// The percent shown, or nil for the sparkles glyph.
  let percent: Int?

  /// The tint.
  let tint: Color

  /// The sphere's diameter.
  var diameter: CGFloat = 150

  /// A caption under the number inside the sphere.
  var caption: String? = nil

  /// Text shown in place of the percent (e.g. an elapsed time).
  var label: String? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var breathing = false
  @State private var shown = 0

  private var isStill: Bool {
    return reduceMotion || ProcessInfo.processInfo.arguments.contains("--uitest-seed")
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(RadialGradient(colors: [tint.opacity(0.42), tint.opacity(0.0)], center: .center, startRadius: diameter * 0.16, endRadius: diameter * 0.7))
        .frame(width: diameter * 1.4, height: diameter * 1.4)
        .scaleEffect(breathing ? 1.05 : 0.97)

      Circle()
        .fill(RadialGradient(colors: [tint.opacity(0.95), tint.opacity(0.35)], center: .center, startRadius: 4, endRadius: diameter * 0.55))
        .frame(width: diameter, height: diameter)
        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .scaleEffect(breathing ? 1.03 : 0.99)

      VStack(spacing: 0) {
        if let percent = percent {
          Text("\(shown)%")
            .font(.system(size: diameter * 0.3, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
            .onAppear {
              if isStill {
                shown = percent
              }
              else {
                withAnimation(.easeOut(duration: 0.9)) { shown = percent }
              }
            }
            .onChange(of: percent) { _, newValue in
              withAnimation(isStill ? nil : .easeOut(duration: 0.6)) { shown = newValue }
            }
        }
        else if let label = label {
          Text(label)
            .font(.system(size: diameter * 0.2, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, diameter * 0.1)
        }
        else {
          Image(systemName: "sparkles")
            .font(.system(size: diameter * 0.26, weight: .semibold))
        }
        if let caption = caption {
          Text(caption)
            .font(.system(size: max(diameter * 0.085, 11), weight: .semibold, design: .rounded))
            .opacity(0.9)
            .monospacedDigit()
        }
      }
      .foregroundStyle(.white)
    }
    .frame(height: diameter * 1.3)
    .onAppear {
      guard !isStill else {
        return
      }
      withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
        breathing = true
      }
    }
  }

}

/// The last two days of forecasts flowing into the next 24 hours: a line for
/// what the model said, then the 24-hour window drawn as a plateau at today's
/// chance with its likely range as a band, and the 12-hour chance as a dashed
/// shorter plateau.
struct RiskRibbon: View {

  let history: [HeadacheManager.RiskHistoryPoint]
  let probability: Double
  let probability12: Double?
  let interval: RiskInterval?
  let now: Date
  let tint: Color

  private static let past: TimeInterval = 48.0 * 3600.0
  private static let future: TimeInterval = 24.0 * 3600.0

  private struct Point: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
  }

  private var points: [Point] {
    var points = history
      .filter({ $0.date >= now.addingTimeInterval(-RiskRibbon.past) && $0.date < now.addingTimeInterval(-60) })
      .map({ Point(date: $0.date, value: $0.probability) })
    points.append(Point(date: now, value: probability))
    return points
  }

  private var yTop: Double {
    let highest = max(points.map({ $0.value }).max() ?? 0.0, interval?.upper ?? 0.0, probability12 ?? 0.0)
    return min(1.0, max(0.4, highest + 0.08))
  }

  var body: some View {
    VStack(spacing: Tokens.Spacing.xxs) {
      Chart {
        ForEach(points) { point in
          AreaMark(x: .value("Time", point.date), yStart: .value("Floor", 0.0), yEnd: .value("Risk", point.value), series: .value("Series", "past"))
            .interpolationMethod(.monotone)
            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
          LineMark(x: .value("Time", point.date), y: .value("Risk", point.value), series: .value("Series", "past"))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .foregroundStyle(tint)
        }

        if let interval = interval {
          RectangleMark(
            xStart: .value("Now", now),
            xEnd: .value("End", now.addingTimeInterval(RiskRibbon.future)),
            yStart: .value("Lower", interval.lower),
            yEnd: .value("Upper", interval.upper))
          .foregroundStyle(tint.opacity(0.18))
        }

        RuleMark(xStart: .value("Now", now), xEnd: .value("End", now.addingTimeInterval(RiskRibbon.future)), y: .value("24h", probability))
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .foregroundStyle(tint)

        if let probability12 = probability12 {
          RuleMark(xStart: .value("Now", now), xEnd: .value("12h", now.addingTimeInterval(RiskRibbon.future / 2.0)), y: .value("12h", probability12))
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3.0, 3.0]))
            .foregroundStyle(tint.opacity(0.75))
        }

        RuleMark(x: .value("Now", now))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [2.0, 3.0]))
          .foregroundStyle(Color.secondary.opacity(0.6))

        PointMark(x: .value("Now", now), y: .value("Risk", probability))
          .symbol {
            Circle()
              .fill(tint)
              .frame(width: 9, height: 9)
              .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
          }
      }
      .chartXScale(domain: now.addingTimeInterval(-RiskRibbon.past) ... now.addingTimeInterval(RiskRibbon.future))
      .chartYScale(domain: 0.0 ... yTop)
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: 64)

      GeometryReader { geometry in
        let nowX = geometry.size.width * CGFloat(RiskRibbon.past / (RiskRibbon.past + RiskRibbon.future))
        ZStack(alignment: .topLeading) {
          Text("2 days ago")
          Text("Now")
            .fixedSize()
            .position(x: nowX, y: 6)
          Text("Next 24h")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
      .font(.caption2)
      .foregroundColor(.secondary)
      .frame(height: 14)
    }
    .padding(.horizontal, Tokens.Spacing.gutter)
  }

}
