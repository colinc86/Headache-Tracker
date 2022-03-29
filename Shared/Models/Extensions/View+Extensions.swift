//
//  View+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI

extension View {
  
  /// Overlays a gradient foreground.
  ///
  /// - Parameter colors: The gradient's colors.
  public func gradientForeground(colors: [Color]) -> some View {
    overlay(
      LinearGradient(
        colors: colors,
        startPoint: .bottom,
        endPoint: .top)
    )
      .mask(self)
  }
  
  /// Sets the view's color theme.
  ///
  /// - Parameter theme: The color theme.
  /// - Returns: A view with the given color theme.
  func colorTheme(_ theme: ColorTheme) -> some View {
    environment(\.colorTheme, theme)
  }
  
}
