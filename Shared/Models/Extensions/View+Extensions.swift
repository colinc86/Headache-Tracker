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
  
  /// Sets the view's debug settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func debugSettings(_ settings: AppSettings.DebugSettings) -> some View {
    environment(\.debugSettings, settings)
  }
  
  /// Sets the view's general settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func generalSettings(_ settings: AppSettings.GeneralSettings) -> some View {
    environment(\.generalSettings, settings)
  }
  
  /// Sets the view's headache settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func headacheSettings(_ settings: AppSettings.HeadacheSettings) -> some View {
    environment(\.headacheSettings, settings)
  }
  
  /// Sets the view's health settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func healthSettings(_ settings: AppSettings.HealthSettings) -> some View {
    environment(\.healthSettings, settings)
  }
  
  /// Sets the view's list settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func listSettings(_ settings: AppSettings.ListSettings) -> some View {
    environment(\.listSettings, settings)
  }
  
  /// Sets the view's notification settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func notificationSettings(_ settings: AppSettings.NotificationSettings) -> some View {
    environment(\.notificationSettings, settings)
  }
  
  /// Sets the view's filter settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func filterSettings(_ settings: AppSettings.FilterSettings) -> some View {
    environment(\.filterSettings, settings)
  }
  
  /// Sets the view's prediction settings.
  ///
  /// - Parameter settings: The settings.
  /// - Returns: A view with the given settings.
  func predictionSettings(_ settings: AppSettings.PredictionSettings) -> some View {
    environment(\.predictionSettings, settings)
  }
  
}
