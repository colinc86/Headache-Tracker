//
//  StatusCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

struct StatusCard: View {
  
  /// The headache's resolution status.
  let resolved: Bool
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Status",
      systemImage: "face.smiling.fill",
      foregroundColor: colorTheme.teal
    ) {
      Text(resolved ? "Resolved" : "Unresolved")
        .font(.title)
        .foregroundColor(colorTheme.baseColor)
    }
  }
  
}

struct StatusCard_Previews: PreviewProvider {
  static var previews: some View {
    StatusCard(resolved: true)
      .previewLayout(.fixed(width: 428, height: 70))
    
    StatusCard(resolved: false)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
