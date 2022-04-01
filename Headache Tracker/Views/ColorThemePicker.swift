//
//  ColorSchemePicker.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

struct ColorThemePicker: View {
  
  /// The theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  // MARK: View body
  
  var body: some View {
    Form {
      Picker("Theme", selection: $colorTheme) {
        ForEach(ColorTheme.allCases) { theme in
          ColorThemeView(theme: theme, titleAlignment: .leading).tag(theme)
        }
      }
      .pickerStyle(InlinePickerStyle())
    }
    .onChange(of: colorTheme, perform: { _ in presentationMode.wrappedValue.dismiss() })
    .listStyle(DefaultListStyle())
    .navigationBarTitleDisplayMode(.inline)
  }
  
}

struct ColorThemePicker_Previews: PreviewProvider {
  @State static var theme: ColorTheme = .system
  static var previews: some View {
    NavigationView {
      ColorThemePicker()
    }
  }
}
