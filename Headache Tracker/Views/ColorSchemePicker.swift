//
//  ColorSchemePicker.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

struct ColorSchemePicker: View {
  
  @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) var colorScheme: AppColorScheme = .multicolor
  
  var body: some View {
    Form {
      Picker("Theme", selection: $colorScheme) {
        ForEach(AppColorScheme.allCases) { scheme in
          ColorSchemeView(scheme: scheme, titleAlignment: .leading).tag(scheme)
        }
      }
      .pickerStyle(InlinePickerStyle())
      .onChange(of: colorScheme, perform: { _ in presentationMode.wrappedValue.dismiss() })
    }
    .listStyle(DefaultListStyle())
  }
  
}

struct ColorSchemePicker_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ColorSchemePicker()
    }
  }
}
