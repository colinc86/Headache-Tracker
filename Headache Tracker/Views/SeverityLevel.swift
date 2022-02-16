//
//  SeverityLevel.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI
import HealthKit

/// Draws a vertical severity level indicator.
struct SeverityLevel: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  @StateObject var headache: Headache
  
  // MARK: View body
  
  var body: some View {
    GeometryReader { geometry in
      HStack {
        Spacer(minLength: 0.0)
        VStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            if 4 - i < headache.severityRange.0.orderingValue ||
                4 - i > headache.severityRange.1.orderingValue {
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

extension SeverityLevel {
  
  /// Gets the color for the severity index.
  ///
  /// - Parameter index: The index of the severity.
  /// - Returns: A color.
  private func color(for index: Int) -> Color {
    return (HKCategoryValueSeverity(rawValue: index) ?? .notPresent).uiColor
  }
  
}

struct SeverityLevel_Previews: PreviewProvider {
  static var previews: some View {
    SeverityLevel(headache: Previewing.CoreData.headache)
      .previewLayout(PreviewLayout.fixed(width: 20, height: 50))
  }
}
