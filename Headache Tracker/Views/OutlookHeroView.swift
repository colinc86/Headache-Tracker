//
//  OutlookHeroView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI

/// The living "Outlook" hero: a breathing risk orb with an aura glow, a
/// rolling probability number, and the tier — the app's daily forecast at a
/// glance. Carries the app icon's aura motif. Continuous motion is disabled
/// under Reduce Motion.
struct OutlookHeroView: View {

  /// The forecast to present.
  let outlook: RiskOutlook

  /// The headline accuracy shown beside the confidence grade.
  var accuracy: ForecastAccuracy? = nil

  // MARK: Private properties

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var breathing = false
  @State private var shownProbability = 0

  /// The hero's tint, tracking the risk tier (mirrors `OutlookView.tint`).
  private var tint: Color {
    switch outlook {
    case .risk(let prediction):
      guard prediction.probability >= 0 else { return .secondary }
      return colorTheme.color(for: prediction.tier)
    case .activeHeadache(let severity, _):
      return colorTheme.color(for: severity)
    }
  }

  /// The probability percent, or nil when there's no forecast.
  private var percent: Int? {
    if case .risk(let prediction) = outlook, prediction.probability >= 0 {
      return Int((prediction.probability * 100).rounded())
    }
    return nil
  }

  /// One coherent VoiceOver announcement for the hero. Without grouping, the
  /// orb's percent is read separately from the caption (which repeats it), and
  /// the empty-state `sparkles` glyph reads as meaningless noise; the caption
  /// already carries the percent, so title + caption reads cleanly.
  private var accessibilityLabel: String {
    var label = outlook.title
    if let caption = outlook.caption {
      label += ". \(caption)"
    }
    if let prediction = forecast {
      if let interval = prediction.interval {
        label += ", \(interval.spokenText)"
      }
      if let accuracy = accuracy {
        label += ". The model has been \(accuracy.spokenText)"
      }
      label += ". Confidence: \(prediction.confidence.title)."
    }
    return label
  }

  /// The forecast behind the hero, when it is showing one with a range or a
  /// coverage reading to grade.
  private var forecast: RiskPrediction? {
    guard case .risk(let prediction) = outlook, prediction.probability >= 0, prediction.interval != nil || prediction.coverage != nil else {
      return nil
    }
    return prediction
  }

  // MARK: View body

  var body: some View {
    VStack(spacing: Tokens.Spacing.md) {
      orb
      VStack(spacing: 2) {
        Text(outlook.title)
          .font(.title3.weight(.semibold))
        if let caption = outlook.caption {
          Text(caption)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        if let prediction = forecast {
          HStack(spacing: Tokens.Spacing.sm) {
            Text(([prediction.interval.map({ "Likely \($0.rangeText)" }), accuracy?.text].compactMap({ $0 })).joined(separator: " · "))
              .font(.caption.monospacedDigit())
              .foregroundColor(.secondary)
            ForecastConfidenceBadge(confidence: prediction.confidence)
          }
          .padding(.top, Tokens.Spacing.xxs)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Tokens.Spacing.lg)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .onAppear {
      // No continuous motion under Reduce Motion or during UI tests (a
      // repeatForever animation would keep XCUITest from ever settling). The
      // number's own reveal lives on the orb's Text below — pre-setting it here
      // would race that count-up and negate it.
      guard !reduceMotion, !ProcessInfo.processInfo.arguments.contains("--uitest-seed") else { return }
      withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
        breathing = true
      }
    }
  }

  private var orb: some View {
    ZStack {
      // Aura: a radial gradient that fades fully to clear at its own edge, so
      // it stays inside the frame. (A blurred solid circle bled past the row
      // bounds and got hard-clipped at the top and bottom of the card.)
      Circle()
        .fill(RadialGradient(colors: [tint.opacity(0.42), tint.opacity(0.0)], center: .center, startRadius: 28, endRadius: 120))
        .frame(width: 240, height: 240)
        .scaleEffect(breathing ? 1.05 : 0.97)

      // Orb.
      Circle()
        .fill(RadialGradient(colors: [tint.opacity(0.95), tint.opacity(0.35)], center: .center, startRadius: 4, endRadius: 95))
        .frame(width: 172, height: 172)
        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .scaleEffect(breathing ? 1.03 : 0.99)

      // Value.
      if let percent = percent {
        Text("\(shownProbability)%")
          .font(.system(size: 52, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .contentTransition(.numericText())
          .onAppear {
            // Count up from zero on first reveal — but honor Reduce Motion and
            // keep UI-test snapshots deterministic by settling immediately.
            if reduceMotion || ProcessInfo.processInfo.arguments.contains("--uitest-seed") {
              shownProbability = percent
            }
            else {
              withAnimation(.easeOut(duration: 0.9)) { shownProbability = percent }
            }
          }
          .onChange(of: percent) { newValue in
            if reduceMotion {
              shownProbability = newValue
            }
            else {
              withAnimation(.easeOut(duration: 0.6)) { shownProbability = newValue }
            }
          }
      }
      else {
        Image(systemName: "sparkles")
          .font(.system(size: 44, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))
      }
    }
    .frame(height: 240)
  }
}

/// A compact "how your risk evolved" sparkline: a filled trend line that
/// draws itself in. Values are probabilities (0–1), oldest → newest.
struct RiskSparkline: View {

  let values: [Double]
  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var trim: CGFloat = 0

  private var maxY: Double { max(values.max() ?? 0.4, 0.35) }

  /// A spoken summary of the trend for VoiceOver — the line itself is a
  /// pure shape with no text, so without this the chart is invisible to
  /// assistive tech.
  private var accessibilityDescription: String {
    guard let last = values.last else {
      return "No forecast history yet."
    }
    let now = Int((last * 100).rounded())
    guard let first = values.first, values.count >= 2 else {
      return "Now \(now) percent."
    }
    let then = Int((first * 100).rounded())
    let trend: String
    if last > first + 0.02 { trend = "up from \(then) percent" }
    else if last < first - 0.02 { trend = "down from \(then) percent" }
    else { trend = "holding near \(then) percent" }
    return "Now \(now) percent, \(trend)."
  }

  var body: some View {
    GeometryReader { geometry in
      let points = points(in: geometry.size)
      ZStack {
        if points.count >= 2 {
          areaPath(points, height: geometry.size.height)
            .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))
            .opacity(Double(trim))
          linePath(points)
            .trim(from: 0, to: trim)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
          if let last = points.last {
            Circle().fill(color).frame(width: 8, height: 8).position(last).opacity(trim >= 0.95 ? 1 : 0)
          }
        }
      }
    }
    .frame(height: 56)
    .onAppear {
      if reduceMotion || ProcessInfo.processInfo.arguments.contains("--uitest-seed") {
        trim = 1
      }
      else {
        withAnimation(.easeOut(duration: 0.75)) { trim = 1 }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Risk trend")
    .accessibilityValue(accessibilityDescription)
  }

  private func points(in size: CGSize) -> [CGPoint] {
    guard values.count >= 2 else { return [] }
    return values.enumerated().map { index, value in
      CGPoint(
        x: size.width * CGFloat(index) / CGFloat(values.count - 1),
        y: size.height * (1 - CGFloat(min(value, maxY) / maxY)))
    }
  }

  private func linePath(_ points: [CGPoint]) -> Path {
    var path = Path()
    path.addLines(points)
    return path
  }

  private func areaPath(_ points: [CGPoint], height: CGFloat) -> Path {
    var path = Path()
    // Trace the line across the top, then drop to the baseline on the right,
    // run back along the baseline, and close up the left edge — so the fill
    // hugs the line. (A leading move(to:) was previously discarded by
    // addLines' own implicit move, which closed the fill on a first→last
    // diagonal instead of the baseline.)
    path.addLines(points)
    path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
    path.addLine(to: CGPoint(x: points[0].x, y: height))
    path.closeSubpath()
    return path
  }
}

struct OutlookHeroView_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 30) {
      OutlookHeroView(outlook: .risk(RiskPrediction(input: .empty, probability: 0.68, topFactors: [], computedAt: Date())))
      OutlookHeroView(outlook: .risk(.empty))
    }
    .padding()
  }
}
