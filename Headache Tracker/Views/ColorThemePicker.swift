//
//  ColorSchemePicker.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

struct ColorThemePicker: View {
  
  /// The theme.
  @Binding var theme: ColorTheme
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  // MARK: View body
  
  var body: some View {
    Form {
      Picker("Theme", selection: $theme) {
        ForEach(ColorTheme.allCases.filter({ $0.multicolor })) { theme in
          ColorThemeView(theme: theme, titleAlignment: .leading).tag(theme)
        }
      }
      .pickerStyle(InlinePickerStyle())
      
      Picker("", selection: $theme) {
        ForEach(ColorTheme.allCases.filter({ !$0.multicolor })) { theme in
          ColorThemeView(theme: theme, titleAlignment: .leading).tag(theme)
        }
      }
      .pickerStyle(InlinePickerStyle())
    }
    .onChange(of: theme, perform: { _ in presentationMode.wrappedValue.dismiss() })
    .listStyle(DefaultListStyle())
    .navigationBarTitleDisplayMode(.inline)
  }
  
}

struct ColorThemePicker_Previews: PreviewProvider {
  @State static var theme: ColorTheme = .system
  static var previews: some View {
    NavigationView {
      ColorThemePicker(theme: $theme)
    }
  }
}
