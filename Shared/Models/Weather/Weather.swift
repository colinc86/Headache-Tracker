//
//  Weather.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

import Foundation
import CoreLocation

class Weather: CustomStringConvertible {
  
  /// A spread of weather data by +/- 6 hrs.
  struct WeatherSpread: Codable, CustomStringConvertible {
    
    /// Weather data contains information about humidity, pressure and temperature.
    struct WeatherData: Codable, CustomStringConvertible {
      var description: String {
        return "{ humidity: \(humidity), pressure: \(pressure), temp: \(temp), datetimeEpoch: \(datetimeEpoch) }"
      }
      
      let humidity: Double
      let pressure: Double
      let temp: Double
      let datetimeEpoch: TimeInterval
    }
    
    /// Weather location structures contain the location that was used to calculate
    /// the weather spread in the weather service.
    struct WeatherLocation: Codable, CustomStringConvertible {
      static let null = WeatherLocation(latitude: 0.0, longitude: 0.0)
      var description: String {
        return "{ latitude: \(latitude), longitude: \(longitude) }"
      }
      let latitude: Double
      let longitude: Double
    }
    
    var description: String {
      return "{ spread: \(spread), location: \(location), current: \(current), future: \(future), past: \(past) }"
    }
    
    let spread: Int
    let location: WeatherLocation
    let current: WeatherData
    let future: WeatherData
    let past: WeatherData
  }
  
  var description: String {
    return "{ spread: \(weatherSpread.description), pressure: \(devicePressure?.formatted() ?? "nil") }"
  }
  
  /// The weather's location.
  var location: CLLocation
  
  /// The weather's spread.
  var weatherSpread: WeatherSpread
  
  /// The weather's device pressure (optional).
  var devicePressure: Measurement<UnitPressure>?
  
  /// The weather statistics.
  var statistics: WeatherStatistics {
    let currentPressure = Measurement(value: weatherSpread.current.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let currentHumidity = weatherSpread.current.humidity
    let currentTemperature = weatherSpread.current.temp
  
    let sigmaHumidity = abs(weatherSpread.current.humidity - weatherSpread.future.humidity) + abs(weatherSpread.current.humidity - weatherSpread.past.humidity)
    
    let cPressure = Measurement(value: weatherSpread.current.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let fPressure = Measurement(value: weatherSpread.future.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let pPressure = Measurement(value: weatherSpread.past.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let sigmaPressure = abs(cPressure - fPressure) + abs(cPressure - pPressure)
    
    let cTemperature = weatherSpread.current.temp
    let fTemperature = weatherSpread.future.temp
    let pTemperature = weatherSpread.past.temp
    let sigmaTemperature = abs(cTemperature - fTemperature) + abs(cTemperature - pTemperature)
    
    return WeatherStatistics(
      barometricPressure: devicePressure?.converted(to: .kilopascals).value,
      currentPressure: currentPressure,
      currentHumidity: currentHumidity,
      currentTemperature: currentTemperature,
      sigmaPressure: sigmaPressure,
      sigmaHumidity: sigmaHumidity,
      sigmaTemperature: sigmaTemperature)
  }
  
  init(location: CLLocation, spread: WeatherSpread, pressure: Measurement<UnitPressure>?) {
    self.location = location
    weatherSpread = spread
    devicePressure = pressure
  }
  
}
