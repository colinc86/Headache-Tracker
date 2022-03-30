//
//  MeasurementSystem.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import Foundation

enum MeasurementSystem: String {
  case metric
  case imperial
  
  var title: String {
    return rawValue.capitalized
  }
  
  var pressureUnit: UnitPressure {
    switch self {
    case .metric: return .millibars
    case .imperial: return .poundsForcePerSquareInch
    }
  }
  
  var temperatureUnit: UnitTemperature {
    switch self {
    case .metric: return .celsius
    case .imperial: return .fahrenheit
    }
  }
  
  var humidityUnit: UnitRate {
    .percent
  }
}
