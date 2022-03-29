//
//  Color+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

extension Color {
  
  // MARK: Types
  
  /// A color component.
  typealias Component = Double
  
  /// A color's components.
  struct Components: Codable {
    /// The color's red component.
    let red: Component
    
    /// The color's green component.
    let green: Component
    
    /// The color's blue component.
    let blue: Component
    
    /// The color's alpha component.
    let alpha: Component
    
    /// The color created by the component.
    var color: Color {
      Color(.displayP3, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    /// Initializes a structure of color components.
    ///
    /// - Parameter color: The color.
    init(_ color: Color) {
      var red: CGFloat = 0.0
      var green: CGFloat = 0.0
      var blue: CGFloat = 0.0
      var alpha: CGFloat = 0.0
      UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }
  }
  
  // MARK: Static properties
  
  /// The brand color.
  static let brandColor = Self(red: 0.129, green: 0.675, blue: 0.808)
  
  // MARK: Computed properties
  
  /// The color's color components.
  var components: Components {
    Components(self)
  }
  
  // MARK: Initializers
  
  /// Creates a color from a structure of color components.
  ///
  /// - Parameter components: The color components.
  init(_ components: Components) {
    self = components.color
  }
  
  // MARK: Methods
  
  /// A grayscale version of the color.
  func grayscale() -> Self {
    let white = 0.299 * components.red + 0.587 * components.green + 0.114 * components.blue
    return Self(.displayP3, white: white, opacity: components.alpha)
  }
  
  /// Adjusts the colors hue by the given percent.
  func adjust(by percent: Double) -> Self {
    return Color(.displayP3,
                 red: max(min(components.red + percent, 1.0), 0.0),
                 green: max(min(components.green + percent, 1.0), 0.0),
                 blue: max(min(components.blue + percent, 1.0), 0.0),
                 opacity: components.alpha)
  }
  
  /// Creates a lighter color.
  func lighter(by percent: Double = 0.1) -> Self {
    adjust(by: percent)
  }
  
  /// Creates a darker color.
  func darker(by percent: Double = 0.1) -> Self {
    adjust(by: -percent)
  }
  
}

// MARK: Codable protocol

extension Color: Codable {
  
  enum CodingKeys: CodingKey {
    case components
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(try container.decode(Components.self, forKey: .components))
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(components, forKey: .components)
  }
  
}
