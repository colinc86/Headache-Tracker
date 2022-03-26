//
//  ActionCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

/// A card that displays a button and performs an action.
struct ActionCardView: View {
  
  /// The card's title.
  let title: String
  
  /// The card's button title.
  let buttonTitle: String
  
  /// The card's image.
  let systemImage: String
  
  /// The card's color.
  let foregroundColor: Color
  
  /// The action to perform when the user taps the no headache button.
  let action: () async throws -> Void
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: title, systemImage: systemImage, foregroundColor: foregroundColor) {
      AsyncButton(buttonTitle, action: action)
        .buttonStyle(BorderlessButtonStyle())
        .font(.title)
        .foregroundColor(foregroundColor)
    }
  }
}

struct ActionView_Previews: PreviewProvider {
  static var previews: some View {
    ActionCardView(title: "Test", buttonTitle: "Test", systemImage: "checkmark", foregroundColor: .teal, action: {})
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
