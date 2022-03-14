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
        return "{ humidity: \(humidity), pressure: \(pressure), temp: \(temp), datetimeEpoch: \(datetimeEpoch) }"
      }
      
      let humidity: Double
      let pressure: Double
      let temp: Double
      let datetimeEpoch: TimeInterval
    }
    
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
    return "{ spread: \(weatherSpread?.description ?? "nil"), pressure: \(devicePressure?.formatted() ?? "nil") }"
  }
  
  var weatherSpread: WeatherSpread?
  var devicePressure: Measurement<UnitPressure>?
  var statistics: WeatherStatistics
  
  init(spread: WeatherSpread?, pressure: Measurement<UnitPressure>?) {
    weatherSpread = spread
    devicePressure = pressure
    
    // Calculate stats
    if let spread = spread {
      let currentPressure = Measurement(value: spread.current.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
      let currentHumidity = Measurement(value: spread.current.humidity, unit: UnitRate.percent).converted(to: .decimal).value
      let currentTemperature = Measurement(value: spread.current.temp, unit: UnitTemperature.kelvin).converted(to: .celsius).value
      
      let sigmaHumidity = (abs(spread.current.humidity - spread.future.humidity) + abs(spread.current.humidity - spread.past.humidity)) / 100.0
      
      let cPressure = Measurement(value: spread.current.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
      let fPressure = Measurement(value: spread.future.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
      let pPressure = Measurement(value: spread.past.pressure, unit: UnitPressure.millibars).converted(to: .kilopascals).value
      let sigmaPressure = abs(cPressure - fPressure) + abs(cPressure - pPressure)
      
      let cTemperature = Measurement(value: spread.current.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
      let fTemperature = Measurement(value: spread.future.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
      let pTemperature = Measurement(value: spread.past.pressure, unit: UnitTemperature.kelvin).converted(to: .celsius).value
      let sigmaTemperature = abs(cTemperature - fTemperature) + abs(cTemperature - pTemperature)
      
      statistics = WeatherStatistics(
        barometricPressure: pressure?.converted(to: .kilopascals).value,
        currentPressure: currentPressure,
        currentHumidity: currentHumidity,
        currentTemperature: currentTemperature,
        sigmaPressure: sigmaPressure,
        sigmaHumidity: sigmaHumidity,
        sigmaTemperature: sigmaTemperature)
    }
    else {
      statistics = WeatherStatistics(
        barometricPressure: pressure?.converted(to: .kilopascals).value,
        currentPressure: nil,
        currentHumidity: nil,
        currentTemperature: nil,
        sigmaPressure: nil,
        sigmaHumidity: nil,
        sigmaTemperature: nil)
    }
  }
  
}
