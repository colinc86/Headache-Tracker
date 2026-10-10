//
//  RiskSparklineStatic.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The app's risk sparkline without its draw-in animation (widgets render
/// once). Values are probabilities (0–1), oldest → newest. In tinted and
/// vibrant rendering the area fill is dropped so the line stays crisp.
struct RiskSparklineStatic: View {

  /// The probabilities, oldest first.
  let values: [Double]

  /// The line's tint.
  let color: Color

  /// The line width.
  var lineWidth: CGFloat = 3.0

  /// Whether to draw the gradient area beneath the line.
  var showsFill = true

  /// The end dot's diameter.
  var endDotSize: CGFloat = 8.0

  @Environment(\.widgetRenderingMode) private var renderingMode

  /// The y-axis ceiling: at least 35% so a quiet stretch doesn't read as
  /// wild swings.
  private var maxY: Double {
    return max(values.max() ?? 0.4, 0.35)
  }

  /// A spoken summary of the trend for VoiceOver.
  var accessibilityDescription: String {
    guard let last = values.last else {
      return "No forecast history yet."
    }
    let now = Int((last * 100.0).rounded())
    guard let first = values.first, values.count >= 2 else {
      return "Now \(now) percent."
    }
    let then = Int((first * 100.0).rounded())
    let trend: String
    if last > first + 0.02 {
      trend = "up from \(then) percent"
    }
    else if last < first - 0.02 {
      trend = "down from \(then) percent"
    }
    else {
      trend = "holding near \(then) percent"
    }
    return "Now \(now) percent, \(trend)."
  }

  var body: some View {
    GeometryReader { geometry in
      let points = points(in: geometry.size)
      ZStack {
        if points.count >= 2 {
          if showsFill && renderingMode == .fullColor {
            areaPath(points, height: geometry.size.height)
              .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))
          }
          linePath(points)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .widgetAccentable()
          if let last = points.last {
            Circle()
              .fill(color)
              .frame(width: endDotSize, height: endDotSize)
              .position(last)
              .widgetAccentable()
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Risk trend")
    .accessibilityValue(accessibilityDescription)
  }

  private func points(in size: CGSize) -> [CGPoint] {
    guard values.count >= 2 else {
      return []
    }
    let inset = endDotSize / 2.0
    return values.enumerated().map { index, value in
      CGPoint(
        x: inset + (size.width - 2.0 * inset) * CGFloat(index) / CGFloat(values.count - 1),
        y: inset + (size.height - 2.0 * inset) * (1.0 - CGFloat(min(value, maxY) / maxY)))
    }
  }

  private func linePath(_ points: [CGPoint]) -> Path {
    var path = Path()
    path.addLines(points)
    return path
  }

  private func areaPath(_ points: [CGPoint], height: CGFloat) -> Path {
    var path = Path()
    path.addLines(points)
    path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
    path.addLine(to: CGPoint(x: points[0].x, y: height))
    path.closeSubpath()
    return path
  }

}
