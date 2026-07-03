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
  
  /// Whether or not the progression view should be drawn expanded.
  @AppStorage(Preferences.Lists.Keys.expandedProgression) private var expanded = Preferences.Lists.Defaults.expanded
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
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
      LineGraph(series: headache.progression, gradient: Gradient(colors: headache.severityColors(for: colorTheme)))
    }
    .frame(height: expanded ? 200 : 50)
  }
}

// MARK: Private methods

extension ProgressionCard {
  
  func expandCollapseAction() {
    withAnimation { expanded.toggle() }
  }
  
}

struct ProgressionCard_Previews: PreviewProvider {
  static var previews: some View {
    ProgressionCard(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.sizeThatFits)
    
    ProgressionCard(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.sizeThatFits)
  }
}
