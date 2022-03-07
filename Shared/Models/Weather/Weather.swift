//
//  Weather.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

import Foundation

class Weather: CustomStringConvertible {
  
  /// A spread of weather data by +/- 6 hrs.
  struct WeatherSpread: Codable, CustomStringConvertible {
    
    struct WeatherData: Codable, CustomStringConvertible {
      var description: String {
        return "{ humidity: \(humidity), pressure: \(pressure), temp: \(temp), dt: \(dt) }"
      }
      
      let humidity: Double
      let pressure: Double
      let temp: Double
      let dt: TimeInterval
    }
    
    struct WeatherLocation: Codable, CustomStringConvertible {
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
    return "{ spread: \(weatherSpread), pressure: \(devicePressure.formatted()) }"
  }
  
  var weatherSpread: WeatherSpread
  var devicePressure: Measurement<UnitPressure>
  
  var currentHumidity: Measurement<UnitRate> {
    return Measurement(value: weatherSpread.current.humidity, unit: .percent)
  }
  
  var currentPressure: Measurement<UnitPressure> {
    return Measurement(value: weatherSpread.current.pressure, unit: UnitPressure.millibars)
  }
  
  var currentTemperature: Measurement<UnitTemperature> {
    return Measurement(value: weatherSpread.current.temp, unit: UnitTemperature.kelvin)
  }
  
  var currentTime: Date {
    return Date(timeIntervalSince1970: weatherSpread.current.dt)
  }
  
  var sigmaHumidity: Double {
    return (abs(weatherSpread.current.humidity - weatherSpread.future.humidity) + abs(weatherSpread.current.humidity - weatherSpread.past.humidity)) / 100.0
  }
  
  var sigmaPressure: Double {
    let cPressure = Measurement(value: weatherSpread.current.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let fPressure = Measurement(value: weatherSpread.future.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    let pPressure = Measurement(value: weatherSpread.past.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
    return abs(cPressure - fPressure) + abs(cPressure - pPressure)
  }
  
  var sigmaTemperature: Double {
    let cTemperature = Measurement(value: weatherSpread.current.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
    let fTemperature = Measurement(value: weatherSpread.future.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
    let pTemperature = Measurement(value: weatherSpread.past.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
    return abs(cTemperature - fTemperature) + abs(cTemperature - pTemperature)
  }
  
  var sigmaTime: TimeInterval {
    return abs(weatherSpread.current.dt - weatherSpread.future.dt) + abs(weatherSpread.current.dt - weatherSpread.past.dt)
  }
  
  init(spread: WeatherSpread, pressure: Measurement<UnitPressure>) {
    weatherSpread = spread
    devicePressure = pressure
  }
  
}
