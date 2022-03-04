//
//  UnitRate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import Foundation

class UnitRate: Dimension {
  static let decimal = UnitRate(symbol: "", converter: UnitConverterLinear(coefficient: 1.0))
  static let percent = UnitRate(symbol: "%", converter: UnitConverterLinear(coefficient: 1e-2))
  
  override class func baseUnit() -> Self {
    return UnitRate.decimal as! Self
  }
}
