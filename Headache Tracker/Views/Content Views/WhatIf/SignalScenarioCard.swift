//
//  SignalScenarioCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import SwiftUI

/// One dimension of the simulation: its scenario value, the current reading,
/// the sensitivity curve, and a continuous slider that snaps onto "now".
struct SignalScenarioCard: View {

  /// The slider thumb's radius, which the curve's plot inset matches so the
  /// markers sit under the thumb.
  static let thumbRadius: CGFloat = 14.0

  /// The dimension.
  let dimension: WhatIfDimension

  /// The scenario value.
  @Binding var value: Double

  /// The current reading.
  let initialValue: Double

  /// The scored curve, holding every other slider where it is.
  let curve: [CurvePoint]

  /// The shared probability domain.
  let yDomain: ClosedRange<Double>

  /// The date the base input was taken at (for time-of-day formatting).
  let referenceDate: Date

  /// Whether a model is available to score.
  let isEnabled: Bool

  /// Removes the dimension; nil for the built-in ones.
  var onRemove: (() -> Void)?

  /// Called when the slider snaps onto the current reading.
  let onSnap: () -> Void

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// Whether the slider is resting on the detent, so the haptic fires once.
  @State private var wasSnapped = true

  private var accent: Color {
    return dimension.kind == .timeOfDay ? colorTheme.purple : colorTheme.baseColor
  }

  /// This slider's own effect: the curve at the scenario value versus at the
  /// current reading, isolating it from the other sliders.
  private var delta: Double? {
    guard value != initialValue,
          let scenario = WhatIfScenario.interpolatedProbability(curve: curve, at: value),
          let now = WhatIfScenario.interpolatedProbability(curve: curve, at: initialValue) else {
      return nil
    }
    return scenario - now
  }

  private var captionText: String {
    guard let swing = WhatIfScenario.swing(of: curve) else {
      return ""
    }
    guard swing >= 0.01 else {
      return "Your forecast barely moves across this range — the model isn't leaning on it right now."
    }
    let points = Int((swing * 100).rounded())
    if let best = curve.min(by: { $0.probability < $1.probability }) {
      return "Swings about \(points) points across this range, lowest around \(dimension.format(best.value, referenceDate: referenceDate))."
    }
    return "Swings about \(points) points across this range."
  }

  var body: some View {
    Card(title: dimension.title, systemImage: dimension.systemImage, foregroundColor: accent) {
      if let onRemove = onRemove {
        Button(action: onRemove) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove \(dimension.title)")
      }
    } content: {
      VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
          Text(dimension.format(value, referenceDate: referenceDate))
            .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          if let delta = delta, abs(delta) >= 0.0005 {
            Text(SignalScenarioCard.deltaText(delta))
              .font(.caption.weight(.semibold).monospacedDigit())
              .foregroundColor(delta < 0 ? colorTheme.green : colorTheme.orange)
              .contentTransition(.numericText())
          }
          Spacer(minLength: 0)
          Chip(title: "now \(dimension.format(initialValue, referenceDate: referenceDate))", style: .readonly)
            .lineLimit(1)
        }

        SensitivityCurve(
          curve: curve,
          xDomain: dimension.range,
          yDomain: yDomain,
          scenarioValue: value,
          nowValue: initialValue,
          tint: accent,
          format: { dimension.format($0, referenceDate: referenceDate) })

        Slider(value: $value, in: dimension.range)
          .tint(accent)
          .disabled(!isEnabled)
          .onChange(of: value) { _, newValue in
            let snapped = WhatIfScenario.snapped(newValue, toward: initialValue, range: dimension.range)
            if snapped != newValue {
              value = snapped
              return
            }
            let isSnapped = snapped == initialValue
            if isSnapped && !wasSnapped {
              onSnap()
            }
            wasSnapped = isSnapped
          }
          .accessibilityLabel(dimension.title)
          .accessibilityValue(dimension.format(value, referenceDate: referenceDate))
      }
    } caption: {
      Text(captionText)
    }
  }

  /// A signed delta in points, with a decimal under one point so a small but
  /// real move isn't rounded into "no change".
  static func deltaText(_ delta: Double) -> String {
    if abs(delta) < 0.01 {
      return String(format: "%+.1f%% vs. now", delta * 100)
    }
    return String(format: "%+.0f%% vs. now", delta * 100)
  }

}

#Preview("Pressure") {
  struct Host: View {
    @State private var value = 101.3
    var body: some View {
      let range = 98.0 ... 104.0
      let curve = WhatIfScenario.sweepValues(in: range, count: 21).enumerated().map { index, x in
        CurvePoint(id: index, value: x, probability: 0.2 + 0.35 * pow((x - 101.3) / 3.0, 2.0))
      }
      return ScrollView {
        SignalScenarioCard(
          dimension: WhatIfDimension(signal: .weather(.currentPressure), range: range, isRemovable: true)!,
          value: $value,
          initialValue: 101.3,
          curve: curve,
          yDomain: WhatIfScenario.sharedYDomain(curves: [curve]),
          referenceDate: Date(),
          isEnabled: true,
          onRemove: {},
          onSnap: {})
      }
      .background(Color(UIColor.systemGroupedBackground))
    }
  }
  return Host()
}
