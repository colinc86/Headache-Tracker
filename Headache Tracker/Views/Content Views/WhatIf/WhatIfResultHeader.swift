//
//  WhatIfResultHeader.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import SwiftUI

/// The pinned result: the simulated 24-hour risk as a ring and a number, how
/// far it moved from the live forecast, and the 12-hour value.
struct WhatIfResultHeader: View {

  /// The score of the scenario as it stands.
  let adjusted: ScenarioScore?

  /// The score of the live forecast the scenario started from.
  let base: ScenarioScore?

  /// Whether any slider has moved.
  let isModified: Bool

  /// Whether a model is available to score.
  let isEnabled: Bool

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var probability24: Double? {
    guard let adjusted = adjusted, adjusted.hasModel else {
      return nil
    }
    return adjusted.probability24
  }

  private var tier: RiskPrediction.RiskTier? {
    return probability24.map(RiskPrediction.RiskTier.init(probability:))
  }

  private var tint: Color {
    return tier.map({ colorTheme.color(for: $0) }) ?? .secondary
  }

  private var delta: Double? {
    guard isModified, let adjusted = probability24, let base = base, base.hasModel else {
      return nil
    }
    return adjusted - base.probability24
  }

  /// The range first, then the 12-hour value; whichever exists.
  private var captionText: String {
    var parts = [String]()
    if probability24 != nil, let interval = adjusted?.interval24 {
      parts.append("Likely \(interval.rangeText)")
    }
    parts.append(adjusted?.probability12.map({ "12h · \(Int(($0 * 100).rounded()))%" }) ?? "12h · —")
    return parts.joined(separator: " · ")
  }

  var body: some View {
    HStack(spacing: Tokens.Spacing.lg) {
      RiskRing(
        probability: probability24 ?? 0.0,
        tint: tint,
        lineWidth: 6,
        inner: adjusted?.probability12.map { short in
          RiskRingInner(probability: short, tint: colorTheme.color(for: RiskPrediction.RiskTier(probability: short)), lineWidth: 4)
        },
        band: probability24 == nil ? nil : adjusted?.interval24,
        gap: 3,
        trackOpacity: 0.18
      ) {
        EmptyView()
      }
      .frame(width: 56, height: 56)

      VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
          Text(probability24.map({ "\(Int(($0 * 100).rounded()))%" }) ?? "—")
            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
            .contentTransition(.numericText())
          if let tier = tier {
            Text(tier.title)
              .font(.subheadline.weight(.medium))
              .foregroundColor(tint)
          }
        }

        HStack(spacing: Tokens.Spacing.sm) {
          if let delta = delta {
            if abs(delta) < 0.0005 {
              Text("no measurable change")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            else {
              Chip(title: SignalScenarioCard.deltaText(delta), style: .readonly, tint: delta < 0 ? colorTheme.green : colorTheme.orange)
            }
          }
          else if !isEnabled {
            Text("Simulator asleep until your first training")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          else {
            Text("Move a slider to try a scenario")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Text(captionText)
          .font(.caption.monospacedDigit())
          .foregroundColor(.secondary)
          .contentTransition(.numericText())
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, Tokens.Spacing.gutter)
    .padding(.vertical, Tokens.Spacing.md)
    .background(Color(UIColor.systemGroupedBackground))
    .overlay(alignment: .bottom) {
      Divider()
    }
    .animation(Tokens.Motion.selection, value: probability24)
    .accessibilityElement(children: .combine)
  }

}

#Preview {
  VStack(spacing: 0) {
    WhatIfResultHeader(
      adjusted: ScenarioScore(probability24: 0.48, probability12: 0.33, interval24: RiskInterval(lower: 0.37, upper: 0.59)),
      base: ScenarioScore(probability24: 0.42, probability12: 0.31),
      isModified: true,
      isEnabled: true)
    WhatIfResultHeader(
      adjusted: ScenarioScore(probability24: 0.42, probability12: nil),
      base: ScenarioScore(probability24: 0.42, probability12: nil),
      isModified: false,
      isEnabled: true)
    WhatIfResultHeader(adjusted: nil, base: nil, isModified: false, isEnabled: false)
  }
}
