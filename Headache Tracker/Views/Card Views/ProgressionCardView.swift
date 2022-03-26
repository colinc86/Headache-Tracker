//
//  ProgressionCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct ProgressionCardView: View {
  
  /// The headache to display.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: colorScheme.themeColor(for: .orange)) {
      LineGraph(series: headache.progression, gradient: Gradient(colors: headache.severityColors(for: colorScheme)))
        .frame(height: 100)
    }
  }
}

struct ProgressionCardView_Previews: PreviewProvider {
  static var previews: some View {
    ProgressionCardView(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.fixed(width: 428, height: 150))
  }
}
