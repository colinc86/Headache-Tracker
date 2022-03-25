//
//  BlockGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/6/22.
//

import SwiftUI

struct BlockGraph: View {
  
  // MARK: Public properties
  
  /// The graph's series to plot.
  let series: [Headache.Severity.DatedRange]
  
  /// The earliest date to draw in the graph.
  let earliestDate: Date?
  
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
      
      HStack(spacing: 0.5) {
        ForEach(ranges(), id: \.self) { range in
          VStack(spacing: 0.5) {
            ForEach(0 ..< 5) { i in
              if range == .empty || 4 - i < range.lowerBound.orderingValue || 4 - i > range.upperBound.orderingValue {
                Rectangle()
                  .fill(Color.clear)
              }
              else {
                Rectangle()
                  .fill(LinearGradient(colors: [color(for: 4 - i).darker(by: 0.05), color(for: 4 - i).lighter(by: 0.05)], startPoint: .bottom, endPoint: .top))
              }
            }
          }
        }
      }
    }
  }
  
}

extension BlockGraph {
  
  /// The bar graph's rectangles.
  ///
  /// - Returns: An array of unit points.
  private func ranges() -> [Headache.Severity.Range] {
    guard let earliestDate = earliestDate ?? series.first?.date else {
      return []
    }
    
    let count = Calendar.current.numberOfDaysBetween(earliestDate, and: Date())
    
    guard count > 0 else {
      return []
    }
    
    var ranges = [Headache.Severity.Range]()
    
    for i in 0 ..< count {
      let date = earliestDate.addingTimeInterval(TimeInterval(i) * 86400.0)
      
      // Get the series value on this date
      if let value = series.filter({ Calendar.current.numberOfDaysBetween(date, and: $0.date) == 0 }).first {
        ranges.append(value.range)
      }
      else {
        ranges.append(Headache.Severity.Range.empty)
      }
    }
    
    return ranges
  }
  
  /// Gets the color for the severity index.
  ///
  /// - Parameter index: The index of the severity.
  /// - Returns: A color.
  private func color(for index: Int) -> Color {
    return (Headache.Severity(orderingValue: index) ?? .notPresent).uiColor
  }
  
}

struct BlockGraph_Previews: PreviewProvider {
  static var previews: some View {
    EmptyView()
  }
}
