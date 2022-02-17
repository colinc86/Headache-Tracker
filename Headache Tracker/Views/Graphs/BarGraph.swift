//
//  BarGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct BarGraph: View {
  
  // MARK: Public properties
  
  /// The graph's series to plot.
  let series: [Double]
  
  /// Whether or not the graph should draw the series' average.
  let average: Double?
  
  /// The bar graph's gradient.
  let gradient: Gradient
  
  /// The view's trim for animating its appearance.
  @State private var trim = 0.0
  
  private var max: Double {
    return series.max() ?? 0.0
  }
  
  
    
  var body: some View {
    if series.count > 0 {
      GeometryReader { geometry in
        ZStack {
          Bars(series: series)
            .trim(from: 0.0, to: trim)
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 0.8 * geometry.size.width / CGFloat(series.count))
            .animation(.easeInOut(duration: Double.random(in: 0.0 ... 0.3) + 0.3), value: trim)
            .onAppear(perform: { trim = 1.0 })
          
          if let average = average {
            Path { path in
              path.move(to: CGPoint(x: 0.0, y: (1.0 - average / max) * geometry.size.height))
              path.addLine(to: CGPoint(x: geometry.size.width, y: (1.0 - average / max) * geometry.size.height))
            }
            .stroke(.secondary, lineWidth: 1.0)
          }
        }
      }
    }
    else {
      EmptyView()
    }
  }
  
  func lineWidth(for size: CGSize) -> CGFloat {
    let xStep = size.width / CGFloat(series.count)
    return xStep * 0.8
  }
  
}

struct Bars: Shape {
  struct Line {
    let endpointA: CGPoint
    let endpointB: CGPoint
  }
  
  let series: [Double]
  
  func path(in rect: CGRect) -> Path {
    Path { path in
      for line in pathLines(for: rect.size) {
        path.move(to: CGPoint(x: line.0, y: rect.height))
        path.addLine(to: CGPoint(x: line.0, y: line.1))
      }
    }
  }
  
  init(series: [Double]) {
    self.series = series
  }
}

// MARK: Private methods

extension Bars {
  
  /// The bar graph's rectangles.
  ///
  /// - Returns: An array of unit points.
  func pathLines(for size: CGSize) -> [(CGFloat, CGFloat)] {
    guard let max = series.max(), max > 0.0 && series.count > 0 else {
      return []
    }
    
    let xStep = size.width / CGFloat(series.count)
    var pathLines = [(CGFloat, CGFloat)]()
    
    for i in 0 ..< series.count {
      let seriesValue = series[i]
      let xCenter = xStep * CGFloat(i) + xStep / 2.0
      let yValue = size.height * (1.0 - CGFloat(seriesValue) / max)
      pathLines.append((xCenter, yValue))
    }
    
    return pathLines
  }
  
}

struct BarGraph_Previews: PreviewProvider {
  static var previews: some View {
    BarGraph(series: [1.0, 2.0, 1.5], average: 1.5, gradient: Gradient(colors: [.cyan, .purple]))
  }
}
