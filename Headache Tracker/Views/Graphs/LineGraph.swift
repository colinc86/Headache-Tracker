//
//  LineGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

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
    HStack {
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
      
      Divider().padding(0)
      
      QuadCurve(unitPoints: pathPoints())
        .trim(from: 0.0, to: trim)
        .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 4.0)
        .animation(.easeInOut(duration: 0.5), value: trim)
        .onAppear(perform: { trim = 1.0 })
    }
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
      .mild, .notPresent, .unspecified
    ], gradient: Gradient(colors: [.cyan, .purple]))
      .previewLayout(.fixed(width: 428, height: 200))
  }
}
