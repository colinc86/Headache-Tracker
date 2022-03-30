//
//  ProgressionCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct ProgressionCard: View {
  
  /// The headache to display.
  @StateObject var headache: Headache
  
  /// Whether the view should be drawn expanded.
  @Binding var expanded: Bool
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @Environment(\.colorTheme) private var colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Progression",
      systemImage: "chart.xyaxis.line",
      foregroundColor: colorTheme.orange
    ) {
      Button(action: expandCollapseAction) {
        Image(systemName: expanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
      }
      .buttonStyle(DefaultButtonStyle())
    } content: {
      LineGraph(series: headache.progression, gradient: Gradient(colors: headache.severityColors(for: colorTheme)), collapsed: !expanded)
        .frame(height: expanded ? 100 : 40)
    }
  }
}

// MARK: Private methods

extension ProgressionCard {
  
  func expandCollapseAction() {
    withAnimation { expanded = !expanded }
  }
  
}

struct ProgressionCard_Previews: PreviewProvider {
  static var previews: some View {
    ProgressionCard(headache: Previewing.CoreData.resolvedHeadache, expanded: Previewing.$booleanFalseValue)
      .previewLayout(.fixed(width: 428, height: 90))
    
    ProgressionCard(headache: Previewing.CoreData.resolvedHeadache, expanded: Previewing.$booleanTrueValue)
      .previewLayout(.fixed(width: 428, height: 150))
  }
}
