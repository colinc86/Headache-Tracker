//
//  LineGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Accessibility
import Shapes
import SwiftUI

/// One logged severity, at the time it was logged.
struct DatedSeverity: Identifiable, Equatable {

  /// When the severity was logged.
  let date: Date

  /// The severity.
  let severity: Headache.Severity

  var id: Date {
    return date
  }

}

struct LineGraph: View {

  // MARK: Public properties

  /// The graph's series to plot, in chronological order.
  let series: [DatedSeverity]

  /// The headache's span. Points are positioned by where they fall in it, so
  /// a severity logged ten minutes in and one logged eight hours in read as
  /// far apart as they actually were.
  let span: DateInterval

  /// The line graph's gradient.
  let gradient: Gradient

  // MARK: Private properties

  /// The view's trim for animating its appearance.
  @State private var trim = 0.0

  /// The radius of a logged-severity dot.
  private let dotRadius: CGFloat = 3.0

  // MARK: View body

  var body: some View {
    GeometryReader { geometry in
      HStack {
        if geometry.size.height >= 100 {
          VStack(alignment: .trailing) {
            Text(Headache.Severity.severe.title)
            Spacer()
            Text(Headache.Severity.moderate.title)
            Spacer()
            Text(Headache.Severity.mild.title)
            Spacer()
            Text(Headache.Severity.unspecified.title)
            Spacer()
            Text(Headache.Severity.notPresent.title)
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }

        Divider().padding(0)

        // The curve and the dots share this ZStack's rect, so both are
        // positioned against the plot area rather than the whole view — the
        // label column above consumes part of the HStack's width.
        ZStack {
          QuadCurve(unitPoints: pathPoints())
            .trim(from: 0.0, to: trim)
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 2.0)

          GeometryReader { plot in
            ForEach(loggedPoints()) { point in
              Circle()
                .fill(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top))
                .frame(width: dotRadius * 2.0, height: dotRadius * 2.0)
                .position(
                  x: point.unitPoint.x * plot.size.width,
                  // `Shapes` draws unit y from the bottom; SwiftUI positions
                  // from the top.
                  y: (1.0 - point.unitPoint.y) * plot.size.height)
            }
          }
          .opacity(trim)
        }
        .animation(Tokens.Motion.reveal, value: trim)
        .onAppear(perform: { trim = 1.0 })
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Severity progression")
    .accessibilityValue(accessibilitySummary)
    .accessibilityChartDescriptor(self)
  }

}

// MARK: Accessibility

extension LineGraph: AXChartDescriptorRepresentable {

  /// The spoken summary: start, peak, and end severities.
  var accessibilitySummary: String {
    guard let first = series.first, let last = series.last else {
      return "No data"
    }

    let peak = series.max(by: { $0.severity.orderingValue < $1.severity.orderingValue }) ?? first
    return "Starts \(first.severity.title.lowercased()), peaks at \(peak.severity.title.lowercased()), ends \(last.severity.title.lowercased()). \(series.count) \(series.count == 1 ? "update" : "updates")."
  }

  func makeChartDescriptor() -> AXChartDescriptor {
    let points = series.enumerated().map { index, point in
      AXDataPoint(x: "Update \(index + 1)", y: Double(point.severity.orderingValue), additionalValues: [], label: point.severity.title)
    }

    let xAxis = AXCategoricalDataAxisDescriptor(
      title: "Update",
      categoryOrder: series.indices.map({ "Update \($0 + 1)" }))

    let yAxis = AXNumericDataAxisDescriptor(
      title: "Severity",
      range: 0.0 ... 4.0,
      gridlinePositions: []) { value in
        Headache.Severity(orderingValue: Int(value))?.title ?? ""
      }

    let series = AXDataSeriesDescriptor(name: "Severity progression", isContinuous: true, dataPoints: points)

    return AXChartDescriptor(
      title: "Severity progression",
      summary: accessibilitySummary,
      xAxis: xAxis,
      yAxis: yAxis,
      additionalAxes: [],
      series: [series])
  }

}

// MARK: Private methods

extension LineGraph {

  /// A logged severity paired with its plotted position.
  struct PlottedPoint: Identifiable {
    let id: Date
    let unitPoint: UnitPoint
  }

  /// The unit y for a severity, with `notPresent` at the bottom and `severe`
  /// at the top.
  ///
  /// - Parameter severity: The severity.
  /// - Returns: A unit y in 0...1.
  private static func unitY(for severity: Headache.Severity) -> CGFloat {
    return CGFloat(max(severity.orderingValue, 0)) / 4.0
  }

  /// The unit x for a date within the headache's span.
  ///
  /// - Parameter date: The date.
  /// - Returns: A unit x in 0...1.
  private func unitX(for date: Date) -> CGFloat {
    guard span.duration > 0.0 else {
      return 0.0
    }
    let fraction = date.timeIntervalSince(span.start) / span.duration
    return CGFloat(min(max(fraction, 0.0), 1.0))
  }

  /// The plotted positions of the logged severities (excluding the synthetic
  /// terminal point that holds the last severity out to the span's end).
  ///
  /// - Returns: An array of plotted points.
  func loggedPoints() -> [PlottedPoint] {
    return series.map { point in
      PlottedPoint(
        id: point.date,
        unitPoint: UnitPoint(x: unitX(for: point.date), y: LineGraph.unitY(for: point.severity)))
    }
  }

  /// The line graph's points.
  ///
  /// A severity holds until the next one is logged, so the last severity is
  /// carried to the end of the span as a terminal point. That's both truthful
  /// and what lets a headache with a single severity draw a flat line across
  /// its duration instead of nothing at all.
  ///
  /// - Returns: An array of unit points.
  func pathPoints() -> [UnitPoint] {
    guard !series.isEmpty else {
      return []
    }

    var pathPoints = series.map { point in
      UnitPoint(x: unitX(for: point.date), y: LineGraph.unitY(for: point.severity))
    }

    if let last = series.last {
      let terminal = UnitPoint(x: 1.0, y: LineGraph.unitY(for: last.severity))
      if terminal.x > pathPoints[pathPoints.count - 1].x {
        pathPoints.append(terminal)
      }
    }

    // A single severity logged at the very end of the span (or a zero-length
    // span) collapses to one point, which strokes nothing — hold it flat.
    if pathPoints.count == 1 {
      pathPoints.append(UnitPoint(x: 1.0, y: pathPoints[0].y))
      pathPoints[0] = UnitPoint(x: 0.0, y: pathPoints[0].y)
    }

    return pathPoints
  }

}

struct LineGraph_Previews: PreviewProvider {
  static let start = Date()

  static var multiple: [DatedSeverity] {
    return [
      DatedSeverity(date: start, severity: .mild),
      DatedSeverity(date: start.addingTimeInterval(1_800.0), severity: .notPresent),
      DatedSeverity(date: start.addingTimeInterval(21_600.0), severity: .severe)
    ]
  }

  static var previews: some View {
    LineGraph(
      series: multiple,
      span: DateInterval(start: start, end: start.addingTimeInterval(28_800.0)),
      gradient: Gradient(colors: [.red, .yellow]))
    .previewLayout(.fixed(width: 428, height: 150))
    .previewDisplayName("Several severities")

    // The common case: a brand-new headache with exactly one severity.
    LineGraph(
      series: [DatedSeverity(date: start, severity: .moderate)],
      span: DateInterval(start: start, end: start.addingTimeInterval(7_200.0)),
      gradient: Gradient(colors: [.orange]))
    .previewLayout(.fixed(width: 428, height: 150))
    .previewDisplayName("Single severity")
  }
}
