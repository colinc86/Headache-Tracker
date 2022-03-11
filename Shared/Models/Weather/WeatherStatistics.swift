//
//  WeatherStatistics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

struct WeatherStatistics: Codable, Equatable {
  
  static let empty = WeatherStatistics(barometricPressure: 0.0, currentPressure: 0.0, currentHumidity: 0.0, currentTemperature: 0.0, sigmaPressure: 0.0, sigmaHumidity: 0.0, sigmaTemperature: 0.0)
  
  /// The device's barometric pressure in Kilopascals.
  let barometricPressure: Double
  
  /// The current pressure in Kilopascals.
  let currentPressure: Double
  
  /// The current humidity in decimal percent.
  let currentHumidity: Double
  
  /// The current temperature in degrees celcius.
  let currentTemperature: Double
  
  /// The sigma pressure in Kilopascals.
  let sigmaPressure: Double
  
  /// The sigma humidity in decimal percent.
  let sigmaHumidity: Double
  
  /// The sigma temperature in degrees celcius.
  let sigmaTemperature: Double
}
