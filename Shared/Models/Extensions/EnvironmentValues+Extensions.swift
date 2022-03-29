//
//  EnvironmentValues+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/29/22.
//

import SwiftUI

/// An environment key to set a color theme.
struct ColorThemeKey: EnvironmentKey {
  static let defaultValue = ColorTheme.system
}

extension EnvironmentValues {
  
  /// The color theme to apply.
  var colorTheme: ColorTheme {
    get { self[ColorThemeKey.self] }
    set { self[ColorThemeKey.self] = newValue }
  }
  
}
