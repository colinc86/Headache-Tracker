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
  
}
