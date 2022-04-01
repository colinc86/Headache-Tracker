//
//  ColorTheme.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

/// An application color theme.
struct ColorTheme: Codable, Equatable, Hashable, Identifiable, RawRepresentable {
  
  typealias ObjectIdentifier = String
  typealias RawValue = String
  
  /// Codable coding keys.
  private enum CodingKeys: CodingKey {
    case name
    case multicolor
    case baseColor
    case notPresent
    case unspecified
    case mild
    case moderate
    case severe
    case pink
    case orange
    case green
    case mint
    case cyan
    case indigo
    case purple
    case yellow
    case red
    case teal
  }
  
  // MARK: Public properties
  
  /// The theme's name.
  let name: String
  
  /// Whether or not the theme is a multicolor theme.
  let multicolor: Bool
  
  /// The main color to use with the theme.
  let baseColor: Color
  
  /// The colors to use in a color well.
  var wellColors: [Color] {
    if multicolor {
      return [
        baseColor,
        notPresent,
        unspecified,
        mild,
        moderate,
        severe
      ]
    }
    return [baseColor, severe]
  }
  
  // MARK: Severity colors
  
  let notPresent: Color
  let unspecified: Color
  let mild: Color
  let moderate: Color
  let severe: Color
  
  // MARK: Specific colors
  
  let pink: Color
  let orange: Color
  let green: Color
  let mint: Color
  let cyan: Color
  let indigo: Color
  let purple: Color
  let yellow: Color
  let red: Color
  let teal: Color
  
  /// The theme's identifier.
  var id: ObjectIdentifier {
    name
  }
  
  var rawValue: String {
    do {
      let data = try JSONEncoder().encode(self)
      return String(data: data, encoding: .utf8) ?? ""
    }
    catch {
      logError("Unable to encode color theme: \(error)")
    }
    return ""
  }
  
  // MARK: Initializers
  
  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8) else { return nil }
    
    do {
      self = try JSONDecoder().decode(Self.self, from: data)
    }
    catch {
      logError("Unable to decode color theme: \(error)")
      return nil
    }
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    multicolor = try container.decode(Bool.self, forKey: .multicolor)
    baseColor = try container.decode(Color.self, forKey: .baseColor)
    notPresent = try container.decode(Color.self, forKey: .notPresent)
    unspecified = try container.decode(Color.self, forKey: .unspecified)
    mild = try container.decode(Color.self, forKey: .mild)
    moderate = try container.decode(Color.self, forKey: .moderate)
    severe = try container.decode(Color.self, forKey: .severe)
    cyan = try container.decode(Color.self, forKey: .cyan)
    mint = try container.decode(Color.self, forKey: .mint)
    yellow = try container.decode(Color.self, forKey: .yellow)
    orange = try container.decode(Color.self, forKey: .orange)
    red = try container.decode(Color.self, forKey: .red)
    pink = try container.decode(Color.self, forKey: .pink)
    green = try container.decode(Color.self, forKey: .green)
    indigo = try container.decode(Color.self, forKey: .indigo)
    purple = try container.decode(Color.self, forKey: .purple)
    teal = try container.decode(Color.self, forKey: .teal)
  }
  
  /// Initializes a color theme by specifying all of the theme's colors.
  init(
    name: String,
    multicolor: Bool,
    baseColor: Color,
    notPresent: Color,
    unspecified: Color,
    mild: Color,
    moderate: Color,
    severe: Color,
    cyan: Color = .cyan,
    mint: Color = .mint,
    yellow: Color = .yellow,
    orange: Color = .orange,
    red: Color = .red,
    pink: Color = .pink,
    green: Color = .green,
    indigo: Color = .indigo,
    purple: Color = .purple,
    teal: Color = .teal
  ) {
    self.name = name
    self.multicolor = multicolor
    self.baseColor = baseColor
    self.notPresent = notPresent
    self.unspecified = unspecified
    self.mild = mild
    self.moderate = moderate
    self.severe = severe
    self.pink = pink
    self.orange = orange
    self.green = green
    self.mint = mint
    self.cyan = cyan
    self.indigo = indigo
    self.purple = purple
    self.yellow = yellow
    self.red = red
    self.teal = teal
  }
  
  /// Initializes a color theme by only specifying the specific colors.
  /// The severity colors are set from the cyan, mint, yellow, orange,
  /// and red colors.
  init(
    name: String,
    baseColor: Color,
    cyan: Color = .cyan,
    mint: Color = .mint,
    yellow: Color = .yellow,
    orange: Color = .orange,
    red: Color = .red,
    pink: Color = .pink,
    green: Color = .green,
    indigo: Color = .indigo,
    purple: Color = .purple,
    teal: Color = .teal
  ) {
    self.init(
      name: name,
      multicolor: true,
      baseColor: baseColor,
      notPresent: cyan,
      unspecified: mint,
      mild: yellow,
      moderate: orange,
      severe: red,
      cyan: cyan,
      mint: mint,
      yellow: yellow,
      orange: orange,
      red: red,
      pink: pink,
      green: green,
      indigo: indigo,
      purple: purple,
      teal: teal)
  }
  
  /// Sets all of the colors to the base color and creates variations for
  /// the different severity levels.
  init(
    name: String,
    baseColor: Color,
    variation: Color
  ) {
    self.init(
      name: name,
      multicolor: false,
      baseColor: baseColor,
      notPresent: baseColor.darker(by: 0.5),
      unspecified: baseColor.darker(by: 0.25),
      mild: baseColor,
      moderate: baseColor.lighter(by: 0.25),
      severe: baseColor.lighter(by: 0.5),
      cyan: variation,
      mint: variation,
      yellow: variation,
      orange: variation,
      red: variation,
      pink: variation,
      green: variation,
      indigo: variation,
      purple: variation,
      teal: variation)
  }
  
  // MARK: Methods
  
  /// The severity color to use for the given scheme.
  func color(for severity: Headache.Severity) -> Color {
    switch severity {
    case .notPresent: return notPresent
    case .unspecified: return unspecified
    case .mild: return mild
    case .moderate: return moderate
    case .severe: return severe
    default: return notPresent
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(multicolor, forKey: .multicolor)
    try container.encode(baseColor, forKey: .baseColor)
    try container.encode(notPresent, forKey: .notPresent)
    try container.encode(unspecified, forKey: .unspecified)
    try container.encode(mild, forKey: .mild)
    try container.encode(moderate, forKey: .moderate)
    try container.encode(severe, forKey: .severe)
    try container.encode(cyan, forKey: .cyan)
    try container.encode(mint, forKey: .mint)
    try container.encode(yellow, forKey: .yellow)
    try container.encode(orange, forKey: .orange)
    try container.encode(red, forKey: .red)
    try container.encode(pink, forKey: .pink)
    try container.encode(green, forKey: .green)
    try container.encode(indigo, forKey: .indigo)
    try container.encode(purple, forKey: .purple)
    try container.encode(teal, forKey: .teal)
  }
  
}

extension ColorTheme: CaseIterable {
  
  /// All of the available themes.
  static var allCases: [ColorTheme] = [
    .system,
    .grayscale,
    .monokai,
    .green,
    .indigo,
    .orange,
    .pink,
    .purple,
    .teal
  ]
  
  static let system = ColorTheme(name: "System", baseColor: .brandColor)
  
  static let grayscale = ColorTheme(name: "Grayscale",
                                    multicolor: true,
                                    baseColor: .brandColor.grayscale(),
                                    notPresent: Color(.displayP3, white: 0.1, opacity: 1.0),
                                    unspecified: Color(.displayP3, white: 0.25, opacity: 1.0),
                                    mild: Color(.displayP3, white: 0.5, opacity: 1.0),
                                    moderate: Color(.displayP3, white: 0.75, opacity: 1.0),
                                    severe: Color(.displayP3, white: 0.9, opacity: 1.0),
                                    cyan: .cyan.grayscale(),
                                    mint: .mint.grayscale(),
                                    yellow: .yellow.grayscale(),
                                    orange: .orange.grayscale(),
                                    red: .red.grayscale(),
                                    pink: .pink.grayscale(),
                                    green: .green.grayscale(),
                                    indigo: .indigo.grayscale(),
                                    purple: .purple.grayscale(),
                                    teal: .teal.grayscale())
  
  static let monokai = ColorTheme(name: "Monokai",
                                  baseColor: Color(#colorLiteral(red: 0.4196258187, green: 0.8744947314, blue: 0.9999926686, alpha: 1)),
                                  cyan: Color(#colorLiteral(red: 0.3069736958, green: 0.6911749244, blue: 0.7984278798, alpha: 1)),
                                  mint: Color(#colorLiteral(red: 0.7043241262, green: 0.8942680955, blue: 0.2335832119, alpha: 1)),
                                  yellow: Color(#colorLiteral(red: 0.9236550331, green: 0.88004601, blue: 0.5285701156, alpha: 1)),
                                  orange: Color(#colorLiteral(red: 1, green: 0.6565478444, blue: 0.1519777477, alpha: 1)),
                                  red: Color(#colorLiteral(red: 0.9932487607, green: 0.2645153701, blue: 0.5190249085, alpha: 1)),
                                  pink: Color(#colorLiteral(red: 0.9932487607, green: 0.2645153701, blue: 0.5190249085, alpha: 1)),
                                  green: Color(#colorLiteral(red: 0.7043241262, green: 0.8942680955, blue: 0.2335832119, alpha: 1)),
                                  indigo: Color(#colorLiteral(red: 0.7396259904, green: 0.5995926857, blue: 1, alpha: 1)),
                                  purple: Color(#colorLiteral(red: 0.7302459478, green: 0.1746567488, blue: 0.6364159584, alpha: 1)),
                                  teal: Color(#colorLiteral(red: 0.3069736958, green: 0.6911749244, blue: 0.7984278798, alpha: 1)))
  
  static let green = ColorTheme(name: "Green", baseColor: .green, variation: .green)
  static let indigo = ColorTheme(name: "Indigo", baseColor: .indigo, variation: .indigo)
  static let orange = ColorTheme(name: "Orange", baseColor: .orange, variation: .orange)
  static let pink = ColorTheme(name: "Pink", baseColor: .pink, variation: .pink)
  static let purple = ColorTheme(name: "Purple", baseColor: .purple, variation: .purple)
  static let teal = ColorTheme(name: "Teal", baseColor: .teal, variation: .teal)
  
}
