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
      LineGraph(series: headache.progression, gradient: Gradient(colors: headache.severityColors(for: colorTheme)))
        .frame(height: 100)
    }
  }
}

struct ProgressionCard_Previews: PreviewProvider {
  static var previews: some View {
    ProgressionCard(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.fixed(width: 428, height: 150))
  }
}
