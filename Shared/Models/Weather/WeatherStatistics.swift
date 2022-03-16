//
//  WeatherStatistics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

struct WeatherStatistics: Codable, Equatable {
  
  static let empty = WeatherStatistics(
    barometricPressure: nil,
    currentPressure: nil,
    currentHumidity: nil,
    currentTemperature: nil,
    sigmaPressure: nil,
    sigmaHumidity: nil,
    sigmaTemperature: nil)
  
  /// The device's barometric pressure in Kilopascals.
  let barometricPressure: Double?
  
  /// The current pressure in Kilopascals.
  let currentPressure: Double?
  
  /// The current humidity in decimal percent.
  let currentHumidity: Double?
  
  /// The current temperature in degrees celcius.
  let currentTemperature: Double?
  
  /// The sigma pressure in Kilopascals.
  let sigmaPressure: Double?
  
  /// The sigma humidity in decimal percent.
  let sigmaHumidity: Double?
  
  /// The sigma temperature in degrees celcius.
  let sigmaTemperature: Double?
  
  var pressureMeasurement: Measurement<UnitPressure>? {
    let pressure = barometricPressure ?? currentPressure
    guard let pressure = pressure else {
      return nil
    }
    return Measurement(value: pressure, unit: .kilopascals)
  }
  var temperatureMeasurement: Measurement<UnitTemperature>? {
    guard let currentTemperature = currentTemperature else {
      return nil
    }
    return Measurement(value: currentTemperature, unit: .celsius)
  }
  var humidityMeasurement: Measurement<UnitRate>? {
    guard let currentHumidity = currentHumidity else {
      return nil
    }
    return Measurement(value: currentHumidity, unit: .decimal)
  }
}
