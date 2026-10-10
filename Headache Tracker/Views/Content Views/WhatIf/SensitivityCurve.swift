//
//  SensitivityCurve.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import Charts
import SwiftUI

/// Risk versus one signal's value, with the current reading marked hollow
/// and the scenario value marked solid. The plot is inset by the slider's
/// thumb radius so its width matches the thumb's travel exactly, the x-axis
/// is pinned to the slider's range (Swift Charts' automatic domain includes
/// zero and squeezed curves far from it), and every curve on the screen
/// shares one y-domain so a flat curve reads as flat.
struct SensitivityCurve: View {

  /// The scored points.
  let curve: [CurvePoint]

  /// The slider's range.
  let xDomain: ClosedRange<Double>

  /// The shared probability domain.
  let yDomain: ClosedRange<Double>

  /// The scenario value.
  let scenarioValue: Double

  /// The current reading.
  let nowValue: Double

  /// The curve's tint.
  let tint: Color

  /// Formats a value on the x-axis.
  let format: (Double) -> String

  /// The horizontal inset matching the slider thumb.
  var plotInset: CGFloat = SignalScenarioCard.thumbRadius

  private var scenarioProbability: Double? {
    return WhatIfScenario.interpolatedProbability(curve: curve, at: scenarioValue)
  }

  private var nowProbability: Double? {
    return WhatIfScenario.interpolatedProbability(curve: curve, at: nowValue)
  }

  var body: some View {
    VStack(spacing: Tokens.Spacing.xxs) {
      chart
        .frame(height: 72)
      HStack {
        Text(format(xDomain.lowerBound))
        Spacer()
        Text(format(xDomain.upperBound))
      }
      .font(.caption2)
      .foregroundColor(.secondary)
      .padding(.horizontal, plotInset)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sensitivity curve")
    .accessibilityValue(accessibilityDescription)
  }

  @ViewBuilder private var chart: some View {
    if curve.count > 1 {
      Chart {
        ForEach(curve) { point in
          AreaMark(
            x: .value("Value", point.value),
            yStart: .value("Floor", yDomain.lowerBound),
            yEnd: .value("Risk", point.probability))
          .interpolationMethod(.monotone)
          .foregroundStyle(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))

          LineMark(
            x: .value("Value", point.value),
            y: .value("Risk", point.probability))
          .interpolationMethod(.monotone)
          .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
          .foregroundStyle(tint)
        }

        RuleMark(x: .value("Now", nowValue))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [3.0, 3.0]))
          .foregroundStyle(Color.secondary.opacity(0.5))

        if let probability = nowProbability {
          PointMark(x: .value("Now", nowValue), y: .value("Risk", probability))
            .symbol {
              Circle()
                .strokeBorder(tint, lineWidth: 2.0)
                .background(Circle().fill(Color(UIColor.systemBackground)))
                .frame(width: 10, height: 10)
            }
        }

        if let probability = scenarioProbability {
          PointMark(x: .value("Scenario", scenarioValue), y: .value("Risk", probability))
            .symbol {
              Circle()
                .fill(tint)
                .frame(width: 12, height: 12)
            }
        }
      }
      .chartXScale(domain: xDomain)
      .chartYScale(domain: yDomain)
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .chartPlotStyle { plot in
        plot.padding(.horizontal, plotInset)
      }
      .overlay(alignment: .topTrailing) {
        // The y-axis top, drawn inside the plot so it never narrows it, on a
        // translucent pill so it stays legible when the curve peaks there.
        Text("\(Int((yDomain.upperBound * 100).rounded()))%")
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.horizontal, Tokens.Spacing.xs)
          .padding(.vertical, 1)
          .background(Capsule().fill(Color(UIColor.systemBackground).opacity(0.85)))
          .padding(.trailing, plotInset)
      }
      .animation(Tokens.Motion.selection, value: scenarioValue)
    }
    else {
      RoundedRectangle(cornerRadius: Tokens.Radius.sm)
        .fill(Color(UIColor.tertiarySystemFill))
        .overlay {
          Text("Scoring…")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
  }

  private var accessibilityDescription: String {
    guard let swing = WhatIfScenario.swing(of: curve) else {
      return "Not scored yet."
    }
    let scenario = scenarioProbability.map({ "\(Int(($0 * 100).rounded())) percent" }) ?? "unknown"
    return "Risk \(scenario) at \(format(scenarioValue)). Swings \(Int((swing * 100).rounded())) points across the range."
  }

}
