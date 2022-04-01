//
//  ActionCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

/// A card that displays a button and performs an action.
struct ActionCard: View {
  
  /// The card's title.
  let title: String
  
  /// The card's button title.
  let buttonTitle: String
  
  /// The card's image.
  let systemImage: String
  
  /// The action to perform when the user taps the no headache button.
  let action: () async throws -> Void
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: title,
      systemImage: systemImage,
      foregroundColor: colorTheme.teal
    ) {
      AsyncButton(buttonTitle, action: action)
        .buttonStyle(BorderlessButtonStyle())
        .font(.title)
    }
  }
}

struct ActionCard_Previews: PreviewProvider {
  static var previews: some View {
    ActionCard(title: "Test", buttonTitle: "Test", systemImage: "checkmark", action: {})
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
