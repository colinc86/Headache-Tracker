//
//  VerticalSeverityLevel.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

/// Draws a vertical severity level indicator.
struct VerticalSeverityLevel: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  var range: Headache.Severity.Range
  
  // MARK: View body
  
  var body: some View {
    GeometryReader { geometry in
      HStack {
        Spacer(minLength: 0.0)
        VStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            if range == .empty || 4 - i < range.lowerBound.orderingValue || 4 - i > range.upperBound.orderingValue {
              Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 10.0, height: 10.0)
            }
            else {
              Rectangle()
                .fill(color(for: 4 - i))
                .frame(width: 10.0, height: 10.0)
            }
            
            if i < 4 {
              Spacer(minLength: 0.0)
            }
          }
        }
        Spacer(minLength: 0.0)
      }
    }
  }
}

// MARK: Private methods

extension VerticalSeverityLevel {
  
  /// Gets the color for the severity index.
  ///
  /// - Parameter index: The index of the severity.
  /// - Returns: A color.
  private func color(for index: Int) -> Color {
    return (Headache.Severity(orderingValue: index) ?? .notPresent).uiColor
  }
  
}

struct VerticalSeverityLevel_Previews: PreviewProvider {
  static var previews: some View {
    VerticalSeverityLevel(range: Previewing.CoreData.resolvedHeadache.severityRange)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 20, height: 50))
  }
}
