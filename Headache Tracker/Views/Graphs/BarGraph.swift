//
//  BarGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Surge
import SwiftUI
import HealthKit

struct BarGraph: View {
  
  enum GraphUnit {
    case severity
    case time
    case duration
  }
  
  // MARK: Public properties
  
  /// The graph's unit.
  let graphUnit: GraphUnit
  
  /// The graph's series to plot.
  let statistic: Statistic
  
  /// The y-axis labels to draw
  var yAxis: [String] = []
  
  /// The bar graph's gradient.
  let gradient: Gradient
  
  /// The earliest date of the bar graph.
  var earliestDate: Date? = nil
  
  /// The static maximum that will be drawn.
  var staticMax: Double? = nil
  
  // MARK: Private properties
  
  /// The graph's feedback generator.
  @State var feedbackGenerator: UISelectionFeedbackGenerator?
  
  /// The view's trim for animating its appearance.
  @State private var trim = 0.0
  
  /// The current touch location.
  @State private var touchLocation: CGPoint?
  
  /// The selected date of the bar graph.
  @State private var selectedDate: Date?
  
  /// The selected value of the bar graph.
  @State private var selectedValue: Double?
  
  /// The max to use.
  private var max: Double {
    return staticMax ?? statistic.max
  }
  
  // MARK: View body
    
  var body: some View {
    HStack {
      VStack(alignment: .trailing) {
        ForEach(0 ..< yAxis.count, id: \.self) { i in
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
          Bars(series: statistic.signal, earliestDate: earliestDate, staticMax: staticMax)
            .trim(from: 0.0, to: trim)
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 0.9 * geometry.size.width / CGFloat(statistic.count))
            .animation(.easeInOut(duration: Double.random(in: 0.0 ... 0.3) + 0.3), value: trim)
            .onAppear(perform: { trim = 1.0 })
            .onTouch(limitToBounds: true) { location, type in
              touched(size: geometry.size, location: location, type: type)
            }
          
          // Mean/trend
          Path { path in
            if statistic.meanTrend.isSteady {
              path.move(to: CGPoint(x: 0.0, y: (1.0 - statistic.meanTrend.valueA / max) * geometry.size.height))
              path.addLine(to: CGPoint(x: geometry.size.width, y: (1.0 - statistic.meanTrend.valueA / max) * geometry.size.height))
            }
            else {
              path.move(to: CGPoint(x: 0.0, y: (1.0 - statistic.meanTrend.valueA / max) * geometry.size.height))
              path.addLine(to: CGPoint(x: geometry.size.width / 2.0, y: (1.0 - statistic.meanTrend.valueA / max) * geometry.size.height))
              
              path.move(to: CGPoint(x: geometry.size.width / 2.0, y: (1.0 - statistic.meanTrend.valueB / max) * geometry.size.height))
              path.addLine(to: CGPoint(x: geometry.size.width, y: (1.0 - statistic.meanTrend.valueB / max) * geometry.size.height))
            }
          }
          .stroke(style: StrokeStyle(lineWidth: 1.0, dash: [5]))
          .foregroundColor(Color(UIColor.tertiaryLabel))
          
          // Touch
          if let touchLocation = touchLocation {
            Path { path in
              path.move(to: CGPoint(x: touchLocation.x, y: 0.0))
              path.addLine(to: CGPoint(x: touchLocation.x, y: geometry.size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [5]))
            .foregroundColor(Color(UIColor.secondaryLabel))
            
            if let selectedDate = selectedDate {
              Text(selectedDate.formattedDate())
                .font(.caption)
                .foregroundColor(.secondary)
                .offset(x: touchLocation.x - geometry.size.width / 2.0, y: geometry.size.height / 2.0 + 8.0)
            }
            
            if let selectedValue = selectedValue, let displayString = displayString(for: selectedValue) {
              Text(displayString)
                .font(.caption)
                .foregroundColor(.secondary)
                .offset(x: touchLocation.x - geometry.size.width / 2.0, y: -geometry.size.height / 2.0 - 10.0)
            }
          }
        }
      }
      .padding(.leading, 4)
    }
  }
  
}

extension BarGraph {
  
  /// Called when the bar shape view is touched.
  ///
  /// - Parameters:
  ///   - size: The view's size.
  ///   - location: The touche's location.
  ///   - type: The touche's event type.
  private func touched(size: CGSize, location: CGPoint, type: TouchLocatingView.TouchType) {
    let updateLocation = {
      guard let earliestDate = earliestDate ?? statistic.signal.first?.1 else {
        return
      }
      
      let count = Calendar.current.numberOfDaysBetween(earliestDate, and: Date())
      
      guard count > 0 else {
        return
      }
      
      let xStep = size.width / CGFloat(count)
      let currentIndex = floor(location.x / xStep)
      let xLocation = currentIndex * xStep + xStep / 2.0
      let currentXLocation = touchLocation?.x ?? -1.0
      
      if xLocation != currentXLocation {
        feedbackGenerator?.selectionChanged()
        feedbackGenerator?.prepare()
      }
      
      let date = earliestDate.addingTimeInterval(TimeInterval(currentIndex) * 86400.0)
      selectedDate = date
      selectedValue = statistic.signal.filter({ Calendar.current.numberOfDaysBetween(date, and: $0.1) == 0 }).first?.0
      touchLocation = CGPoint(x: xLocation, y: location.y)
    }
    
    switch type {
    case .started:
      feedbackGenerator = UISelectionFeedbackGenerator()
      feedbackGenerator?.prepare()
      updateLocation()
    case .moved:
      updateLocation()
    default:
      touchLocation = nil
      feedbackGenerator = nil
    }
  }
  
  /// The string to display when the user selects a value.
  ///
  /// - Parameter value: The selected value.
  /// - Returns: The string to display.
  private func displayString(for value: Double) -> String? {
    switch graphUnit {
    case .severity:
      return HKCategoryValueSeverity(orderingValue: Int(value))?.title
    case .time:
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(value).formattedTime()
    case .duration:
      return Formatters.dateComponentsFormatter.string(from: value)
    }
  }
  
}

struct Bars: Shape {
  
  struct Line {
    let endpointA: CGPoint
    let endpointB: CGPoint
  }
  
  /// The series to plot.
  let series: [(Double, Date)]
  
  /// The earliest date in the series.
  let earliestDate: Date?
  
  /// The maximum value in the series.
  let staticMax: Double?

  /// The maximum value to use when calculating values.
  private var max: Double {
    return staticMax ?? Surge.max(series.map({ $0.0 }))
  }
  
  func path(in rect: CGRect) -> Path {
    Path { path in
      for line in pathLines(for: rect.size) {
        path.move(to: CGPoint(x: line.0, y: rect.height))
        path.addLine(to: CGPoint(x: line.0, y: line.1))
      }
    }
  }
  
  init(series: [(Double, Date)], earliestDate: Date?, staticMax: Double?) {
    self.series = series
    self.earliestDate = earliestDate
    self.staticMax = staticMax
  }
}

// MARK: Private methods

extension Bars {
  
  /// The bar graph's rectangles.
  ///
  /// - Returns: An array of unit points.
  func pathLines(for size: CGSize) -> [(CGFloat, CGFloat)] {
    guard let earliestDate = earliestDate ?? series.first?.1 else {
      return []
    }
    
    let count = Calendar.current.numberOfDaysBetween(earliestDate, and: Date())
    
    guard max > 0.0 && count > 0 else {
      return []
    }
    
    let xStep = size.width / CGFloat(count)
    var pathLines = [(CGFloat, CGFloat)]()
    
    for i in 0 ..< count {
      let date = earliestDate.addingTimeInterval(TimeInterval(i) * 86400.0)
      
      // Get the series values on this date
      let values = series.filter({ Calendar.current.numberOfDaysBetween(date, and: $0.1) == 0 })
      
      // Get the maximum series value
      let seriesValue = values.max(by: { $0.0 < $1.0 })?.0 ?? 0.0
      let xCenter = xStep * CGFloat(i) + xStep / 2.0
      let yValue = size.height * (1.0 - CGFloat(seriesValue) / max)
      pathLines.append((xCenter, yValue))
    }
    
    return pathLines
  }
  
}

struct BarGraph_Previews: PreviewProvider {
  static var previews: some View {
    BarGraph(
      graphUnit: .severity,
      statistic: Statistic(earliestDate: Date().addingTimeInterval(-605.0), signal: [1.0, 2.0, 4.0], dates: [Date().addingTimeInterval(-600.0), Date().addingTimeInterval(-300.0), Date()]),
      yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
      gradient: Gradient(colors: [.cyan, .purple]),
      earliestDate: Date().addingTimeInterval(-605.0),
      staticMax: 4)
      .previewLayout(.fixed(width: 428, height: 200))
  }
}
