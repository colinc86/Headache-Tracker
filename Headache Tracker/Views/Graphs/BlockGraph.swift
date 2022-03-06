//
//  BlockGraph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/6/22.
//

import SwiftUI
import HealthKit

struct BlockGraph: View {
  
  // MARK: Public properties
  
  /// The graph's series to plot.
  let series: [(SeverityRange, Date)]
  
  /// The earliest date to draw in the graph.
  let earliestDate: Date?
  
  // MARK: View body
  
  var body: some View {
    HStack {
      VStack(alignment: .trailing) {
        Text(HKCategoryValueSeverity.severe.title)
        Spacer()
        Text(HKCategoryValueSeverity.moderate.title)
        Spacer()
        Text(HKCategoryValueSeverity.mild.title)
        Spacer()
        Text(HKCategoryValueSeverity.unspecified.title)
        Spacer()
        Text(HKCategoryValueSeverity.notPresent.title)
      }
      .font(.caption)
      .foregroundColor(.secondary)
      
      Divider().padding(0)
      
      HStack {
        ForEach(ranges(), id: \.self) { range in
          VerticalSeverityLevel(range: range)
        }
      }
    }
  }
  
}

extension BlockGraph {
  
  /// The bar graph's rectangles.
  ///
  /// - Returns: An array of unit points.
  func ranges() -> [SeverityRange] {
    guard let earliestDate = earliestDate ?? series.first?.1 else {
      return []
    }
    
    let count = Calendar.current.numberOfDaysBetween(earliestDate, and: Date())
    
    guard count > 0 else {
      return []
    }
    
    var ranges = [SeverityRange]()
    
    for i in 0 ..< count {
      let date = earliestDate.addingTimeInterval(TimeInterval(i) * 86400.0)
      
      // Get the series value on this date
      if let value = series.filter({ Calendar.current.numberOfDaysBetween(date, and: $0.1) == 0 }).first {
        ranges.append(value.0)
      }
      else {
        ranges.append(SeverityRange.empty)
      }
    }
    
    return ranges
  }
  
}

struct BlockGraph_Previews: PreviewProvider {
  static var previews: some View {
    EmptyView()
  }
}
