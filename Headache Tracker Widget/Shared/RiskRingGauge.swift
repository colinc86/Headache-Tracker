//
//  RiskRingGauge.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The shared `RiskRing` with WidgetKit's rendering behaviour: in tinted and
/// vibrant rendering the outer ring and the center take the accent, and the
/// inner ring falls back to a translucent primary so the two horizons stay
/// distinguishable without colour.
struct RiskRingGauge<Center: View>: View {

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

  /// The plausible range around the 24-hour probability.
  var band: RiskInterval? = nil

  /// The clear gap between the rings.
  var gap: CGFloat = 4.0

  /// The track's opacity.
  var trackOpacity: Double = 0.16

  /// The content drawn in the middle.
  @ViewBuilder let center: () -> Center

  @Environment(\.widgetRenderingMode) private var renderingMode

  var body: some View {
    RiskRing(
      probability: probability,
      tint: tint,
      lineWidth: lineWidth,
      inner: inner,
      band: band,
      gap: gap,
      trackOpacity: trackOpacity,
      monochrome: renderingMode != .fullColor
    ) {
      center()
        .widgetAccentable()
    }
    .widgetAccentable()
  }

}
