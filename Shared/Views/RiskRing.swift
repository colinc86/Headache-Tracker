//
//  RiskRing.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import SwiftUI

/// The inner (12-hour) ring of a `RiskRing`.
struct RiskRingInner {
  let probability: Double
  let tint: Color
  var lineWidth: CGFloat = 5.0
}

/// A static ring gauge: a trimmed circle for the 24-hour probability with an
/// optional inner ring for the 12-hour horizon. Starts at 12 o'clock and
/// fills clockwise. Shared by the app (the what-if header) and the widgets
/// (through `RiskRingGauge`, which adds the WidgetKit accent behaviour).
struct RiskRing<Center: View>: View {

  /// The inner (12-hour) ring.
  typealias Inner = RiskRingInner

  /// The 24-hour probability.
  let probability: Double

  /// The outer ring's tint.
  let tint: Color

  /// The outer ring's stroke width.
  var lineWidth: CGFloat = 8.0

  /// The inner ring, when the 12-hour forecast exists.
  var inner: Inner? = nil

  /// The plausible range around the 24-hour probability, drawn as a
  /// translucent band under the value arc.
  var band: RiskInterval? = nil

  /// The clear gap between the rings.
  var gap: CGFloat = 4.0

  /// The track's opacity.
  var trackOpacity: Double = 0.16

  /// Whether to draw without colour (tinted and vibrant widget rendering):
  /// the inner ring falls back to a translucent primary so the two horizons
  /// stay distinguishable.
  var monochrome = false

  /// The content drawn in the middle.
  @ViewBuilder let center: () -> Center

  var body: some View {
    ZStack {
      Circle()
        .stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
        .padding(lineWidth / 2.0)
      if let band = band {
        Circle()
          .trim(from: clamped(band.lower), to: clamped(band.upper))
          .stroke(monochrome ? Color.primary.opacity(0.25) : tint.opacity(0.28), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
          .rotationEffect(.degrees(-90.0))
          .padding(lineWidth / 2.0)
      }
      Circle()
        .trim(from: 0.0, to: clamped(probability))
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90.0))
        .padding(lineWidth / 2.0)

      if let inner = inner {
        let inset = lineWidth + gap + inner.lineWidth / 2.0
        Circle()
          .stroke((monochrome ? Color.primary : inner.tint).opacity(trackOpacity), lineWidth: inner.lineWidth)
          .padding(inset)
        Circle()
          .trim(from: 0.0, to: clamped(inner.probability))
          .stroke(monochrome ? Color.primary.opacity(0.45) : inner.tint, style: StrokeStyle(lineWidth: inner.lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90.0))
          .padding(inset)
      }

      center()
    }
    .aspectRatio(1.0, contentMode: .fit)
  }

  private func clamped(_ value: Double) -> CGFloat {
    return CGFloat(min(max(value, 0.0), 1.0))
  }

}
