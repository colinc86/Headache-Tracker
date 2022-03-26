//
//  ProgressionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct ProgressionView: View {
  
  @StateObject var headache: Headache
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  var body: some View {
    TitleCaptionView(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: colorScheme.themeColor(for: .orange)) {
      LineGraph(series: headache.progression, gradient: Gradient(colors: headache.severityColors(for: colorScheme)))
        .frame(height: 100)
    }
  }
}

struct ProgressionView_Previews: PreviewProvider {
  static var previews: some View {
    ProgressionView(headache: Previewing.CoreData.resolvedHeadache)
      .previewLayout(.fixed(width: 428, height: 150))
  }
}
