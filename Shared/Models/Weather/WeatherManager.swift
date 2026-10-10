//
//  WeatherManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

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
  
  /// Gets the weather at a location.
  ///
  /// - Parameters:
  ///   - date: The date of the weather reading.
  ///   - location: The location.
  ///   - trailing: Extra history to fetch before the window that ends at
  ///     `date`, so one fetch can serve several rows (the back-fill).
  /// - Returns: The weather.
  func weather(at date: Date = Date(), for location: CLLocation, trailing: TimeInterval = 0.0) async throws -> Weather {
    logInfo("Get weather.")
    let spread = try await getWeatherSpread(location: location, date: date, trailing: trailing)
    
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

extension WeatherManager {
  
  /// Gets the weather spread from the weather API.
  ///
  /// - Parameters:
  ///   - location: The location to get the spread for.
  ///   - date: The date of the weather reading.
  /// - Returns: The weather spread.
  private func getWeatherSpread(location: CLLocation, date: Date, trailing: TimeInterval = 0.0) async throws -> Weather.WeatherSpread {
    // Fetch the full trailing window the temporal-context columns need; the
    // 6h sigma fields keep their meaning by picking the point nearest -6h.
    let sixHoursAgo = date.addingTimeInterval(-60 * 60 * 6)
    let windowStart = date.addingTimeInterval(-max(trailing, 0.0) - TimeInterval(WindowStatisticsCalculator.bucketCount) * WindowStatisticsCalculator.bucketLength)
    let weather = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: windowStart, endDate: date))

    guard let lastWeather = weather.last,
          let firstWeather = weather.min(by: { abs($0.date.timeIntervalSince(sixHoursAgo)) < abs($1.date.timeIntervalSince(sixHoursAgo)) }) else {
      throw WeatherError.unknown
    }

    let hourly = weather.map { hour in
      Weather.WeatherSpread.WeatherData(
        humidity: hour.humidity,
        pressure: hour.pressure.converted(to: .millibars).value,
        temp: hour.temperature.converted(to: .celsius).value,
        datetimeEpoch: hour.date.timeIntervalSince1970)
    }

    let pastWeather = Weather.WeatherSpread.WeatherData(
      humidity: firstWeather.humidity,
      pressure: firstWeather.pressure.converted(to: .millibars).value,
      temp: firstWeather.temperature.converted(to: .celsius).value,
      datetimeEpoch: firstWeather.date.timeIntervalSince1970)
    
    let currentWeather = Weather.WeatherSpread.WeatherData(
      humidity: lastWeather.humidity,
      pressure: lastWeather.pressure.converted(to: .millibars).value,
      temp: lastWeather.temperature.converted(to: .celsius).value,
      datetimeEpoch: lastWeather.date.timeIntervalSince1970)
    
    logDebug("Past weather \(pastWeather)")
    logDebug("Current weather \(currentWeather)")
    
    return Weather.WeatherSpread(
      // Hours between `past` and `current` — matches the fetch window above.
      spread: 6,
      location: Weather.WeatherSpread.WeatherLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
      current: currentWeather,
      past: pastWeather,
      hourly: hourly)
  }
  
}
