//
//  AppColorScheme.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

/// An application color scheme.
enum AppColorScheme: String, Equatable, Identifiable {
  
  typealias ObjectIdentifier = RawValue
  
  /// The amount of light/dark tint to apply to the main color.
  static let spread = 0.5
  
  /// All of the colors in the order they should be presented.
  static let allCases: [AppColorScheme] = [
    .multicolor,
    .grayscale,
    .accentColor,
    .pink,
    .orange,
    .yellow,
    .brown,
    .green,
    .mint,
    .teal,
    .indigo,
    .purple
  ]
  
  case multicolor
  case grayscale
  case accentColor
  case pink
  case mint
  case indigo
  case teal
  case orange
  case yellow
  case green
  case brown
  case purple
  
  var id: ObjectIdentifier {
    rawValue
  }
  
  /// The color's title.
  var title: String {
    switch self {
    case .multicolor: return "Multicolor"
    case .grayscale: return "Grayscale"
    case .accentColor: return "Accent"
    case .pink: return "Pink"
    case .mint: return "Mint"
    case .indigo: return "Indigo"
    case .teal: return "Teal"
    case .orange: return "Orange"
    case .yellow: return "Yellow"
    case .green: return "Green"
    case .brown: return "Brown"
    case .purple: return "Purple"
    }
  }
  
  /// The colors to use in a color well.
  var wellColors: [Color] {
    switch self {
    case .multicolor: return [.pink, .yellow, .green, .teal, .purple]
    default: return [color.lighter(by: AppColorScheme.spread), color.darker(by: AppColorScheme.spread)]
    }
  }
  
  /// The background color to use in a color well.
  var backgroundColor: Color {
    switch self {
    case .multicolor: return Color(uiColor: .systemBackground)
    default: return color
    }
  }
  
  /// The theme's main color.
  var color: Color {
    switch self {
    case .multicolor: return .white
    case .accentColor: return .brandColor
    case .pink: return .pink
    case .mint: return .mint
    case .indigo: return .indigo
    case .teal: return .teal
    case .orange: return .orange
    case .yellow: return .yellow
    case .green: return .green
    case .brown: return .brown
    case .grayscale: return .gray
    case .purple: return .purple
    }
  }
  
  /// The theme color to use for the given scheme.
  func themeColor(for color: Color) -> Color {
    return self == .multicolor ? color : self.color
  }
  
  /// The severity color to use for the given scheme.
  func severityColor(for severity: Headache.Severity) -> Color {
    switch severity {
    case .notPresent: return self == .multicolor ? Color.headacheSeverityNotPresent : color.darker(by: 0.5)
    case .unspecified: return self == .multicolor ? Color.headacheSeverityPresent : color.darker(by: 0.25)
    case .mild: return self == .multicolor ? Color.headacheSeverityMild : color
    case .moderate: return self == .multicolor ? Color.headacheSeverityModerate : color.lighter(by: 0.25)
    case .severe: return self == .multicolor ? Color.headacheSeveritySevere : color.lighter(by: 0.5)
    default: return self == .multicolor ? Color.headacheSeverityNotPresent : color.darker(by: 0.5)
    }
  }
  
}
