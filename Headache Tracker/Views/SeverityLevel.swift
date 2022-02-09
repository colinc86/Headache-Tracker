//
//  SeverityLevel.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

/// Draws a vertical severity level indicator.
struct SeverityLevel: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  @StateObject var headache: Headache
  
  // MARK: View body
  
  var body: some View {
    VStack {
      Spacer(minLength: 0.0)
      ForEach(1 ..< 5) { i in
        if 5 - i < headache.severityRange.0.orderingValue ||
            5 - i > headache.severityRange.1.orderingValue {
          Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 10.0, height: 10.0)
        }
        else {
          Rectangle()
            .fill(color(for: 5 - i))
            .frame(width: 10.0, height: 10.0)
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
    switch index {
    case 1: return .cyan
    case 2: return .yellow
    case 3: return .orange
    case 4: return .red
    default: return .cyan
    }
  }
  
}

struct SeverityLevel_Previews: PreviewProvider {
  static var previews: some View {
    SeverityLevel(headache: Previewing.CoreData.headache)
  }
}
