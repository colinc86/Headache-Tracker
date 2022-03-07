//
//  UIColor+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import UIKit

extension UIColor {
  
  /// Adjusts the receiver's color by the given percent.
  ///
  /// - Parameter percent: The percent to adjust by.
  /// - Returns: An adjusted color.
  func adjust(by percent: CGFloat) -> UIColor {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    
    if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
      return UIColor(red: max(min(red + percent, 1.0), 0.0),
                     green: max(min(green + percent, 1.0), 0.0),
                     blue: max(min(blue + percent, 1.0), 0.0),
                     alpha: alpha)
    }
    else {
      return self
    }
  }
  
}
