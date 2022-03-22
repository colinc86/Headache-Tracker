//
//  ProgressionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct ProgressionView: View {
  
  @StateObject var headache: Headache
  
  var body: some View {
    TitleCaptionView(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: .orange) {
      LineGraph(series: headache.severitySignal, gradient: Gradient(colors: headache.severityColorRange))
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
