//
//  TagButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

/// A button that houses a hashtag.
struct TagButton: View {
  
  /// The tag to display.
  let tag: String
  
  /// The button's action.
  let action: (String) -> Void
  
  // MARK: View body
  
  var body: some View {
    Button("#" + tag) {
      action(tag)
    }
  }
  
  // MARK: Initializers
  
  init(_ tag: String, action: @escaping (String) -> Void) {
    self.tag = tag
    self.action = action
  }
  
}

// MARK: Styles

/// A button style used with hashtags.
struct TagButtonStyle: ButtonStyle {
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(colorTheme.baseColor.opacity(configuration.isPressed ? 0.5 : 1.0))
      .padding([.leading, .trailing], 4)
  }
}

/// A button style used with hashtags that should be deleted when tapped.
struct DeletableTagButtonStyle: ButtonStyle {
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      Image(systemName: "xmark.circle")
        .foregroundColor(Color(UIColor.systemBackground).opacity(0.7))
      configuration.label
    }
    .padding(4)
    .padding(.trailing, 4)
    .foregroundColor(Color(uiColor: .systemBackground))
    .background(colorTheme.baseColor.opacity(configuration.isPressed ? 0.5 : 1.0))
    .clipShape(Capsule())
  }
}

// MARK: Previews

struct TagButton_Previews: PreviewProvider {
  
  static var previews: some View {
    TagButton("testtag") { _ in
      logDebug("Tapped testtag.")
    }
    .buttonStyle(TagButtonStyle())
    .previewLayout(.sizeThatFits)
    
    TagButton("testtag") { _ in
      logDebug("Tapped testtag.")
    }
    .buttonStyle(DeletableTagButtonStyle())
    .previewLayout(.sizeThatFits)
  }
}
