//
//  OnsetCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct OnsetCard: View {
  
  /// The view's onset.
  let onset: Date
  
  /// Whether the title should be printed as a relative date.
  var relativeDate: Bool = true
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Onset",
      systemImage: "clock.fill",
      foregroundColor: colorTheme.purple
    ) {
      Text(relativeDate ? onset.formattedRelative() : onset.formattedNonRelative())
        .font(.title)
    }
  }
}

struct OnsetCard_Previews: PreviewProvider {
  static var previews: some View {
    OnsetCard(onset: Date(timeIntervalSinceNow: -3600.0))
      .previewLayout(.fixed(width: 428, height: 70))
    
    OnsetCard(onset: Date(timeIntervalSinceNow: -3600.0), relativeDate: false)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
