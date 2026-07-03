//
//  LineGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Accessibility
import Shapes
import SwiftUI

struct LineGraph: View {
  
  // MARK: Public properties
  
  /// The graph's series to plot.
  let series: [Headache.Severity]
  
  /// The line graph's gradient.
  let gradient: Gradient
  
  // MARK: Private properties
  
  /// The view's trim for animating its appearance.
  @State private var trim = 0.0
  
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
        
        QuadCurve(unitPoints: pathPoints())
          .trim(from: 0.0, to: trim)
          .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 2.0)
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

    let peak = series.max(by: { $0.orderingValue < $1.orderingValue }) ?? first
    return "Starts \(first.title.lowercased()), peaks at \(peak.title.lowercased()), ends \(last.title.lowercased()). \(series.count) updates."
  }

  func makeChartDescriptor() -> AXChartDescriptor {
    let points = series.enumerated().map { index, severity in
      AXDataPoint(x: "Update \(index + 1)", y: Double(severity.orderingValue), additionalValues: [], label: severity.title)
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
  
  /// The line graph's points.
  /// 
  /// - Returns: An array of unit points.
  func pathPoints() -> [UnitPoint] {
    guard series.count > 1 else {
      return []
    }
    
    let xStep = 1.0 / CGFloat(series.count - 1)
    var pathPoints = [UnitPoint]()
    for i in 0 ..< series.count {
      let seriesValue = series[i]
      let xValue = xStep * CGFloat(i)
      let yValue = CGFloat(seriesValue.orderingValue) / 4.0
      pathPoints.append(UnitPoint(x: xValue, y: yValue))
    }
    return pathPoints
  }
  
}

struct LineGraph_Previews: PreviewProvider {
  static var previews: some View {
    LineGraph(series: [
      .mild, .notPresent, .severe
    ], gradient: Gradient(colors: [.red, .yellow]))
    .previewLayout(.fixed(width: 428, height: 50))
    
    LineGraph(series: [
      .mild, .notPresent, .severe
    ], gradient: Gradient(colors: [.red, .yellow]))
    .previewLayout(.fixed(width: 428, height: 150))
  }
}
