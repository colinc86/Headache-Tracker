//
//  ActionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

struct ActionView: View {
  
  let title: String
  
  let buttonTitle: String
  
  let systemImage: String
  
  var foregroundColor: Color = .accentColor
  
  /// The action to perform when the user taps the no headache button.
  let action: () async throws -> Void
  
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
    ActionView(title: "Test", buttonTitle: "Test", systemImage: "check", foregroundColor: .teal, action: {})
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
