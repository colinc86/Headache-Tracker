//
//  BarGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Surge
import SwiftUI

struct BarGraph: View {
  
  // MARK: Public properties
  
  /// The graph's series to plot.
  let statistic: Statistic
  
  /// The y-axis labels to draw
  var yAxis: [String] = []
  
  /// The bar graph's gradient.
  let gradient: Gradient
  
  /// The static number of elements that will be drawn.
  var staticCount: Int? = nil
  
  /// The static maximum that will be drawn.
  var staticMax: Double? = nil
  
  // MARK: Private properties
  
  /// The view's trim for animating its appearance.
  @State private var trim = 0.0
  
  /// The count to use.
  private var count: Int {
    return staticCount ?? statistic.signal.count
  }
  
  /// The max to use.
  private var max: Double {
    return staticMax ?? statistic.max
  }
  
  // MARK: View body
    
  var body: some View {
    HStack {
      VStack(alignment: .trailing) {
        ForEach(0 ..< yAxis.count) { i in
          Text(yAxis[yAxis.count - i - 1])
            .font(.caption)
            .foregroundColor(.secondary)
          
          if i < yAxis.count - 1 {
            Spacer()
          }
        }
      }
      
      Divider().padding(0)
      
      GeometryReader { geometry in
        ZStack {
          // Bars
          Bars(series: statistic.signal, staticCount: staticCount, staticMax: staticMax)
            .trim(from: 0.0, to: trim)
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 0.9 * geometry.size.width / CGFloat(count))
            .animation(.easeInOut(duration: Double.random(in: 0.0 ... 0.3) + 0.3), value: trim)
            .onAppear(perform: { trim = 1.0 })
          
          // Mean
          Path { path in
            path.move(to: CGPoint(x: 0.0, y: (1.0 - statistic.mean / max) * geometry.size.height))
            path.addLine(to: CGPoint(x: geometry.size.width, y: (1.0 - statistic.mean / max) * geometry.size.height))
          }
          .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [5]))
          .foregroundColor(Color(UIColor.tertiaryLabel))
        }
      }
      .padding(.leading, 4)
    }
  }
  
  func lineWidth(for size: CGSize) -> CGFloat {
    let xStep = size.width / CGFloat(statistic.signal.count)
    return xStep * 0.8
  }
  
}

struct Bars: Shape {
  struct Line {
    let endpointA: CGPoint
    let endpointB: CGPoint
  }
  
  let series: [Double]
  let staticCount: Int?
  let staticMax: Double?
  
  private var count: Int {
    return staticCount ?? series.count
  }

  private var max: Double {
    return staticMax ?? Surge.max(series)
  }
  
  func path(in rect: CGRect) -> Path {
    Path { path in
      for line in pathLines(for: rect.size) {
        path.move(to: CGPoint(x: line.0, y: rect.height))
        path.addLine(to: CGPoint(x: line.0, y: line.1))
      }
    }
  }
  
  init(series: [Double], staticCount: Int?, staticMax: Double?) {
    self.series = series
    self.staticCount = staticCount
    self.staticMax = staticMax
  }
}

// MARK: Private methods

extension Bars {
  
  /// The bar graph's rectangles.
  ///
  /// - Returns: An array of unit points.
  func pathLines(for size: CGSize) -> [(CGFloat, CGFloat)] {
    guard max > 0.0 && count > 0 else {
      return []
    }
    
    let xStep = size.width / CGFloat(count)
    var pathLines = [(CGFloat, CGFloat)]()
    
    let shift = CGFloat(count - series.count) * xStep
    
    for i in 0 ..< series.count {
      let seriesValue = series[i]
      let xCenter = xStep * CGFloat(i) + xStep / 2.0 + shift
      let yValue = size.height * (1.0 - CGFloat(seriesValue) / max)
      pathLines.append((xCenter, yValue))
    }
    
    return pathLines
  }
  
}

struct BarGraph_Previews: PreviewProvider {
  static var previews: some View {
    BarGraph(
      statistic: Statistic(signal: [1.0, 2.0, 4.0]),
      yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
      gradient: Gradient(colors: [.cyan, .purple]),
      staticCount: 10,
      staticMax: 4)
      .previewLayout(.fixed(width: 428, height: 200))
  }
}
