//
//  ContributionRow.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// One signal's part in the forecast: icon, title, a capsule bar scaled to
/// its share of the largest contribution, and the signed percent. Signals
/// without a signed delta (the model-importance fallback) show a direction
/// glyph instead of a bar.
struct ContributionRow: View {

  /// The signal.
  let signal: RiskSnapshot.Signal

  /// The largest |delta| across every signal shown, so bars are comparable.
  let maxMagnitude: Double

  /// The tint for a signal raising risk.
  let raisingTint: Color

  /// The tint for a signal easing risk.
  let easingTint: Color

  /// The icon's tint.
  var iconTint: Color = .primary

  /// Whether to show "today vs. usual" beneath the title.
  var showsCaption = false

  @Environment(\.widgetRenderingMode) private var renderingMode

  private var barTint: Color {
    if renderingMode != .fullColor {
      return signal.isRaising ? .primary : Color.primary.opacity(0.35)
    }
    return (signal.isRaising ? raisingTint : easingTint).opacity(0.85)
  }

  var body: some View {
    HStack(spacing: Tokens.Spacing.sm) {
      Image(systemName: signal.systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(renderingMode == .fullColor ? iconTint : Color.primary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(signal.title)
          .font(.system(.caption, design: .rounded).weight(.medium))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        if showsCaption, let caption = signal.todayVersusUsual {
          Text(caption)
            .font(.system(size: 9, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        if let delta = signal.delta {
          GeometryReader { geometry in
            let width = max(4.0, geometry.size.width * CGFloat(min(abs(delta) / max(maxMagnitude, 0.001), 1.0)))
            ZStack(alignment: .leading) {
              Capsule().fill(.quaternary)
              Capsule().fill(barTint).frame(width: width)
                .widgetAccentable(signal.isRaising)
            }
          }
          .frame(height: 4)
        }
      }

      if let delta = signal.delta {
        Text(RiskFormat.signedPercent(delta))
          .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
          .foregroundStyle(.secondary)
          .fixedSize()
          .frame(minWidth: 30, alignment: .trailing)
      }
      else {
        Image(systemName: signal.isRaising ? "arrow.up" : "arrow.down")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(minWidth: 30, alignment: .trailing)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    let direction = signal.isRaising ? "raising your risk" : "in your favor"
    if let delta = signal.delta {
      return "\(signal.title), \(direction) by \(Int((abs(delta) * 100.0).rounded())) percent."
    }
    return "\(signal.title), \(direction)."
  }

}
