//
//  WidgetChrome.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// Conventions for the risk widgets.
///
/// - Never wrap widget content in the app's `Card`: it draws its own padding,
///   background, and list gutter inside the widget's container background.
/// - Hero widgets (Outlook, Twin Ring) sit on the system background; dense
///   widgets (Horizon, Signals, Risk Clock) sit on the secondary system
///   background so bars and fills read against a slightly deeper surface.
/// - Keep the system content margins (no `contentMarginsDisabled()`); use
///   `Tokens.Spacing` inside.
/// - Numbers use the rounded design and monospaced digits; tier tints always
///   come from the shared `ColorTheme` (`colorTheme.color(for:)`).
/// - Health state (percentages, tier words, signal rows, reasons, headache
///   state, elapsed time) is `privacySensitive`; chrome is not.
/// - Placeholder entries render the elevated sample under
///   `.redacted(reason: .placeholder)`.
/// - In tinted and vibrant rendering, mark the primary ring/arc/bar and the
///   hero number `widgetAccentable`; secondary shapes use a translucent
///   primary so two horizons stay distinguishable without colour.
enum RiskWidgetSurface {

  /// The system background.
  case hero

  /// The secondary system background.
  case dense

  var color: Color {
    switch self {
    case .hero: return Color(uiColor: .systemBackground)
    case .dense: return Color(uiColor: .secondarySystemBackground)
    }
  }

}

extension View {

  /// Applies the widget's container background and font design.
  func riskWidgetChrome(_ surface: RiskWidgetSurface) -> some View {
    return self
      .fontDesign(.rounded)
      .containerBackground(for: .widget) { surface.color }
  }

  /// Dims the data layer of a stale forecast.
  func riskWidgetStale(_ isStale: Bool) -> some View {
    return opacity(isStale ? 0.72 : 1.0)
  }

  /// Redacts placeholder data.
  func riskWidgetPlaceholder(_ isPlaceholder: Bool) -> some View {
    return redacted(reason: isPlaceholder ? .placeholder : [])
  }

}

/// A hairline divider for widget content.
struct WidgetHairline: View {

  var body: some View {
    Rectangle()
      .fill(.quaternary)
      .frame(height: 1)
  }

}

/// A 12-hour forecast chip ("12h · 31%").
struct HorizonChip: View {

  /// The 12-hour probability.
  let probability: Double

  /// The chip's tint.
  let tint: Color

  @Environment(\.widgetRenderingMode) private var renderingMode

  var body: some View {
    Text("12h · \(RiskFormat.percent(probability))")
      .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
      .foregroundStyle(renderingMode == .fullColor ? tint : .primary)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Capsule().fill((renderingMode == .fullColor ? tint : Color.primary).opacity(renderingMode == .fullColor ? 0.18 : 0.12)))
      .privacySensitive()
  }

}
