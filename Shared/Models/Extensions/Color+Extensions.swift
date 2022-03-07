//
//  Color+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

extension Color {
  
  static let headacheSeverityNotPresent = Color(Constants.AssetKeys.headacheSeverityNotPresent)
  static let headacheSeverityPresent = Color(Constants.AssetKeys.headacheSeverityPresent)
  static let headacheSeverityMild = Color(Constants.AssetKeys.headacheSeverityMild)
  static let headacheSeverityModerate = Color(Constants.AssetKeys.headacheSeverityModerate)
  static let headacheSeveritySevere = Color(Constants.AssetKeys.headacheSeveritySevere)
  
  public func lighter(by percent: CGFloat) -> Self {
    Self(UIColor(self).adjust(by: percent))
  }
  
  public func darker(by percent: CGFloat) -> Self {
    Self(UIColor(self).adjust(by: -percent))
  }
  
}
