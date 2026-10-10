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
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The headache's logged severities, in chronological order.
  private var series: [DatedSeverity] {
    return headache.severitiesArray.compactMap { state in
      guard let startTime = state.startTime else {
        return nil
      }
      return DatedSeverity(date: startTime, severity: state.severity)
    }
  }

  // MARK: View body

  var body: some View {
    Card(
      title: "Progression",
      systemImage: "chart.xyaxis.line",
      foregroundColor: colorTheme.orange
    ) {
      if let span = headache.dateInterval, !series.isEmpty {
        LineGraph(
          series: series,
          span: span,
          gradient: Gradient(colors: headache.severityColors(for: colorTheme)))
      }
      else {
        HStack {
          Spacer()
          Text("No severities logged yet.")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
        }
      }
    }
    .frame(height: 200)
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
