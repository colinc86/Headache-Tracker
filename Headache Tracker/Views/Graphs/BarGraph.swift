//
//  BarGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Accessibility
import Surge
import SwiftUI

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
          // Gridlines — subtle horizontal rules aligned with the y-axis
          // labels, matching the Swift Charts elsewhere in the app.
          if yAxis.count > 1 {
            Path { path in
              for i in 0 ..< yAxis.count {
                let y = geometry.size.height * CGFloat(i) / CGFloat(yAxis.count - 1)
                path.move(to: CGPoint(x: 0.0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
              }
            }
            .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
          }

          // Bars
          Bars(series: statistic.signal, earliestDate: earliestDate, staticMax: staticMax)
            .trim(from: 0.0, to: trim)
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top), lineWidth: 0.9 * geometry.size.width / CGFloat(statistic.count))
            .animation(Tokens.Motion.reveal, value: trim)
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
    // One element per graph: VoiceOver reads a summary, and the Audio
    // Graphs rotor gets the full series via the chart descriptor.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityTitle)
    .accessibilityValue(accessibilitySummary)
    .accessibilityChartDescriptor(self)
  }
  
}

// MARK: Accessibility

extension BarGraph: AXChartDescriptorRepresentable {

  /// The graph's spoken title.
  var accessibilityTitle: String {
    switch graphUnit {
    case .severity: return "Severity over time"
    case .time: return "Onset time over time"
    case .duration: return "Duration over time"
    }
  }

  /// The graph's spoken summary: count, peak, and trend.
  var accessibilitySummary: String {
    // `statistic.count` is the number of *days* in the window; the headache
    // count is the number of plotted data points (one per headache).
    let headacheCount = statistic.signal.count
    guard headacheCount > 0 else {
      return "No data"
    }

    var parts = ["\(headacheCount) \(headacheCount == 1 ? "headache" : "headaches")"]
    if let peak = displayString(for: statistic.max) {
      parts.append("peak \(peak)")
    }

    let trend = statistic.meanTrend
    if trend.isSteady {
      parts.append("steady trend")
    }
    else {
      parts.append(trend.valueB > trend.valueA ? "rising trend" : "falling trend")
    }

    return parts.joined(separator: ", ")
  }

  func makeChartDescriptor() -> AXChartDescriptor {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium

    let points = statistic.signal.map { value, date in
      AXDataPoint(x: dateFormatter.string(from: date), y: value, additionalValues: [], label: nil)
    }

    let xAxis = AXCategoricalDataAxisDescriptor(
      title: "Date",
      categoryOrder: statistic.signal.map({ dateFormatter.string(from: $0.1) }))

    let yAxis = AXNumericDataAxisDescriptor(
      title: accessibilityTitle,
      range: 0.0 ... Swift.max(max, 1.0),
      gridlinePositions: []) { value in
        self.displayString(for: value) ?? String(format: "%.1f", value)
      }

    let series = AXDataSeriesDescriptor(name: accessibilityTitle, isContinuous: false, dataPoints: points)

    return AXChartDescriptor(
      title: accessibilityTitle,
      summary: accessibilitySummary,
      xAxis: xAxis,
      yAxis: yAxis,
      additionalAxes: [],
      series: [series])
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
      
      // Inclusive of today (`+ 1`) to match the bars drawn by `Bars`; otherwise
      // the rightmost scrub segment would select the wrong day.
      let count = Calendar.current.numberOfDaysBetween(earliestDate, and: Date()) + 1

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
      
      // Calendar-aware day stepping (DST-safe) from the same start-of-day the
      // bars are bucketed against, so scrubbing a bar always selects its own
      // day — even across a DST transition with `earliestDate` near midnight,
      // where flat 86,400s stepping would drift across a midnight boundary.
      let calendar = Calendar.current
      let date = calendar.date(byAdding: .day, value: Int(currentIndex), to: calendar.startOfDay(for: earliestDate))
        ?? earliestDate.addingTimeInterval(TimeInterval(currentIndex) * 86400.0)
      selectedDate = date
      selectedValue = statistic.signal.filter({ calendar.numberOfDaysBetween(date, and: $0.1) == 0 }).first?.0
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
  func displayString(for value: Double) -> String? {
    switch graphUnit {
    case .severity:
      return Headache.Severity(orderingValue: Int(value))?.title
    case .time:
      return Calendar.current.startOfDay(for: Date()).addingTimeInterval(value).formattedTime()
    case .duration:
      return Formatters.formatInterval(value)
    }
  }
  
}

struct Bars: Shape {

  /// The maximum series value per day, indexed from the earliest date.
  private let dayValues: [Double]

  /// The maximum value to use when calculating values.
  private let maxValue: Double

  func path(in rect: CGRect) -> Path {
    Path { path in
      guard maxValue > 0.0 && !dayValues.isEmpty else {
        return
      }

      let xStep = rect.width / CGFloat(dayValues.count)
      for (i, value) in dayValues.enumerated() {
        let xCenter = xStep * CGFloat(i) + xStep / 2.0
        let yValue = rect.height * (1.0 - CGFloat(value) / maxValue)
        path.move(to: CGPoint(x: xCenter, y: rect.height))
        path.addLine(to: CGPoint(x: xCenter, y: yValue))
      }
    }
  }

  init(series: [(Double, Date)], earliestDate: Date?, staticMax: Double?) {
    // Bucket the series by day once. path(in:) runs on every layout and
    // animation frame; recomputing the day-by-day filter there made
    // scrubbing O(days x series) per frame.
    guard let earliestDate = earliestDate ?? series.first?.1 else {
      dayValues = []
      maxValue = 0.0
      return
    }

    let calendar = Calendar.current
    // `+ 1` makes the day span inclusive of today so a headache logged today is
    // plotted; must stay in lockstep with `Statistic.count` (bar stroke width)
    // and the scrub handler below, or bars and touch targets desync.
    let count = calendar.numberOfDaysBetween(earliestDate, and: Date()) + 1

    var values = [Double](repeating: 0.0, count: Swift.max(count, 0))
    let startDay = calendar.startOfDay(for: earliestDate)
    for (value, date) in series {
      let index = calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: date)).day ?? -1
      if index >= 0 && index < values.count && value > values[index] {
        values[index] = value
      }
    }

    dayValues = values
    maxValue = staticMax ?? (series.isEmpty ? 0.0 : Surge.max(series.map({ $0.0 })))
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
