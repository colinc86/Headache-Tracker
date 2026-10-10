//
//  HeadacheShapeChart.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Charts
import SwiftUI

/// How a headache unfolds: every headache's severity aligned at its onset as
/// a faint step line, with the typical (median) headache drawn bold on top.
struct HeadacheShapeChart: View {

  /// The aligned curves.
  let curves: [ProfileAnalytics.CurvePoint]

  /// The median curve.
  let median: [ProfileAnalytics.CurvePoint]

  /// The hours the chart spans.
  let hours: Double

  /// The tint.
  let tint: Color

  private static let severityLabels: [Int: String] = [2: "Mild", 3: "Moderate", 4: "Severe"]

  var body: some View {
    Chart {
      ForEach(curves) { point in
        LineMark(
          x: .value("Hours", point.hours),
          y: .value("Severity", point.severity),
          series: .value("Headache", "h\(point.series)"))
        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .foregroundStyle(tint.opacity(0.22))
      }

      ForEach(median) { point in
        AreaMark(
          x: .value("Hours", point.hours),
          yStart: .value("Floor", 0.0),
          yEnd: .value("Severity", point.severity),
          series: .value("Headache", "median"))
        .interpolationMethod(.monotone)
        .foregroundStyle(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
        LineMark(
          x: .value("Hours", point.hours),
          y: .value("Severity", point.severity),
          series: .value("Headache", "median"))
        .interpolationMethod(.monotone)
        .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round))
        .foregroundStyle(tint)
      }
    }
    .chartXScale(domain: 0.0 ... max(hours, 1.0))
    .chartYScale(domain: 0.0 ... 4.2)
    .chartYAxis {
      AxisMarks(position: .leading, values: [2.0, 3.0, 4.0]) { value in
        AxisGridLine()
        AxisValueLabel {
          if let level = value.as(Double.self), let label = HeadacheShapeChart.severityLabels[Int(level)] {
            Text(label)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: hours > 6 ? 2.0 : 1.0)) { value in
        AxisGridLine()
        AxisValueLabel {
          if let hour = value.as(Double.self) {
            Text(hour == 0 ? "Onset" : "\(Int(hour))h")
          }
        }
      }
    }
    .frame(height: 180)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    guard let peak = median.max(by: { $0.severity < $1.severity }), peak.severity > 0 else {
      return "Not enough headaches to show a typical shape."
    }
    let level = HeadacheShapeChart.severityLabels[Int(peak.severity.rounded())] ?? "Present"
    let end = median.last(where: { $0.severity > 0 })?.hours ?? 0
    return "A typical headache peaks at \(level.lowercased()) about \(String(format: "%.1f", peak.hours)) hours in and eases by about \(String(format: "%.1f", end)) hours."
  }

}
