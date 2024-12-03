//
//  WeatherManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

import Alamofire
import Foundation
import CoreLocation
import WeatherKit

class WeatherManager {
  
  // MARK: Public properties
  
  /// The manager's motion manager.
  let motionManager = MotionManager()
  
}

extension WeatherManager {
  
  /// Cancels the weather task.
  func cancel() {
    logDebug("Cancel get weather.")
    motionManager.cancel()
  }
  
  /// Gets the current weather at the device.
  ///
  /// - Parameter date: The date of the weather reading.
  /// - Returns: The weather.
  func weather(at date: Date = Date(), for location: CLLocation) async throws -> Weather {
    logInfo("Get weather.")
    let spread = try await getWeatherSpread(location: location, date: date)
    
    // Only get the barometric pressure if the requested date is
    // "near" the current date.
    var pressure: Measurement<UnitPressure>?
    if abs(Date().timeIntervalSince(date)) < 60.0 {
      do {
        pressure = try await motionManager.barometricPressure()
      }
      catch {
        logError("Error getting pressure: \(error)")
      }
    }
    
    return Weather(location: location, spread: spread, pressure: pressure)
  }
  
}

fileprivate struct WeatherAPIParams: Codable {
  let latitude: Double
  let longitude: Double
  let spread: Int
  let time: Int
}

enum MyError: Error {
  case errorA
}

extension WeatherManager {
  
  /// Gets the weather spread from the weather API.
  ///
  /// - Parameters:
  ///   - location: The location to get the spread for.
  ///   - date: The date of the weather reading.
  /// - Returns: The weather spread.
  private func getWeatherSpread(location: CLLocation, date: Date) async throws -> Weather.WeatherSpread {
    let now = Date()
    let sixHoursAgo = now.addingTimeInterval(-60 * 60 * 6)
    let sixHoursFromNow = now.addingTimeInterval(60 * 60 * 6)
    let weather = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: sixHoursAgo, endDate: sixHoursFromNow))
    
    guard let firstWeather = weather.first,
          let lastWeather = weather.last else {
      throw WeatherError.unknown
    }
    
    guard weather.count > 6 else {
      throw WeatherError.unknown
    }
    let middleWeather = weather[6]
    
    let pastWeather = Weather.WeatherSpread.WeatherData(
      humidity: firstWeather.humidity,
      pressure: firstWeather.pressure.converted(to: .millibars).value,
      temp: firstWeather.temperature.converted(to: .celsius).value,
      datetimeEpoch: firstWeather.date.timeIntervalSince1970)
    
    let currentWeather = Weather.WeatherSpread.WeatherData(
      humidity: middleWeather.humidity,
      pressure: middleWeather.pressure.converted(to: .millibars).value,
      temp: middleWeather.temperature.converted(to: .celsius).value,
      datetimeEpoch: middleWeather.date.timeIntervalSince1970)
    
    let futureWeather = Weather.WeatherSpread.WeatherData(
      humidity: lastWeather.humidity,
      pressure: lastWeather.pressure.converted(to: .millibars).value,
      temp: lastWeather.temperature.converted(to: .celsius).value,
      datetimeEpoch: lastWeather.date.timeIntervalSince1970)
    
    logDebug("Past weather \(pastWeather)")
    logDebug("Current weather \(currentWeather)")
    logDebug("Future weather \(futureWeather)")
    
    return Weather.WeatherSpread(
      spread: 12,
      location: Weather.WeatherSpread.WeatherLocation(latitude: 0.0, longitude: 0.0),
      current: currentWeather,
      future: futureWeather,
      past: pastWeather)
  }
  
}
