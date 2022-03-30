//
//  EnvironmentValues+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/29/22.
//

import SwiftUI

extension EnvironmentValues {
  
  /// The color theme to apply.
  var colorTheme: ColorTheme {
    get { self[ColorTheme.EnvKey.self] }
    set { self[ColorTheme.EnvKey.self] = newValue }
  }
  
  /// The application's debug settings.
  var debugSettings: AppSettings.DebugSettings {
    get { self[AppSettings.DebugSettings.EnvKey.self] }
    set { self[AppSettings.DebugSettings.EnvKey.self] = newValue }
  }
  
  /// The application's general settings.
  var generalSettings: AppSettings.GeneralSettings {
    get { self[AppSettings.GeneralSettings.EnvKey.self] }
    set { self[AppSettings.GeneralSettings.EnvKey.self] = newValue }
  }
  
  /// The application's headache settings.
  var headacheSettings: AppSettings.HeadacheSettings {
    get { self[AppSettings.HeadacheSettings.EnvKey.self] }
    set { self[AppSettings.HeadacheSettings.EnvKey.self] = newValue }
  }
  
  /// The application's health settings.
  var healthSettings: AppSettings.HealthSettings {
    get { self[AppSettings.HealthSettings.EnvKey.self] }
    set { self[AppSettings.HealthSettings.EnvKey.self] = newValue }
  }
  
  /// The application's list settings.
  var listSettings: AppSettings.ListSettings {
    get { self[AppSettings.ListSettings.EnvKey.self] }
    set { self[AppSettings.ListSettings.EnvKey.self] = newValue }
  }
  
  /// The application's notification settings.
  var notificationSettings: AppSettings.NotificationSettings {
    get { self[AppSettings.NotificationSettings.EnvKey.self] }
    set { self[AppSettings.NotificationSettings.EnvKey.self] = newValue }
  }
  
  /// The application's filter settings.
  var filterSettings: AppSettings.FilterSettings {
    get { self[AppSettings.FilterSettings.EnvKey.self] }
    set { self[AppSettings.FilterSettings.EnvKey.self] = newValue }
  }
  
  /// The application's prediction settings.
  var predictionSettings: AppSettings.PredictionSettings {
    get { self[AppSettings.PredictionSettings.EnvKey.self] }
    set { self[AppSettings.PredictionSettings.EnvKey.self] = newValue }
  }
  
}
