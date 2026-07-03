//
//  OutlookView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import SwiftUI

struct OutlookView: View {

  /// The view's outlook.
  let outlook: RiskOutlook

  // MARK: Private properties

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The card's tint, tracking the risk tier.
  private var tint: Color {
    switch outlook {
    case .risk(let prediction):
      switch prediction.tier {
      case .low: return colorTheme.mint
      case .elevated: return colorTheme.orange
      case .high: return colorTheme.pink
      }
    case .activeHeadache(let severity, _):
      return colorTheme.color(for: severity)
    }
  }

  // MARK: View body

  var body: some View {
    Card(
      title: "Outlook",
      systemImage: "sun.and.horizon",
      foregroundColor: tint) {
      Text(outlook.title)
        .font(.title)
    } caption: {
      if let caption = outlook.caption {
        Text(caption)
      }
    }
  }

}

struct OutlookView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookView(outlook: .risk(RiskPrediction(input: .empty, probability: 0.12, topFactors: [], computedAt: Date())))
      .previewLayout(.fixed(width: 428, height: 100))

    OutlookView(outlook: .risk(RiskPrediction(input: .empty, probability: 0.72, topFactors: [], computedAt: Date())))
      .previewLayout(.fixed(width: 428, height: 100))

    OutlookView(outlook: .activeHeadache(severity: .moderate, since: Date(timeIntervalSinceNow: -3600.0)))
      .previewLayout(.fixed(width: 428, height: 100))
  }
}
