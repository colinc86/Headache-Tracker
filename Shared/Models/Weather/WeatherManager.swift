//
//  WeatherManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

import Alamofire
import Foundation
import CoreLocation

class WeatherManager {
  
  // MARK: Public properties
  
  /// The manager's motion manager.
  let motionManager = MotionManager()
  
  // MARK: Private properties
  
  /// The manager's weather spread URL task.
  private var weatherSpreadTask: URLSessionTask?
  
}

extension WeatherManager {
  
  /// Cancels the weather task.
  func cancel() {
    logDebug("Cancel get weather.")
    motionManager.cancel()
    weatherSpreadTask?.cancel()
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

extension WeatherManager {
  
  /// Gets the weather spread from the weather API.
  ///
  /// - Parameters:
  ///   - location: The location to get the spread for.
  ///   - date: The date of the weather reading.
  /// - Returns: The weather spread.
  private func getWeatherSpread(location: CLLocation, date: Date) async throws -> Weather.WeatherSpread {
    let url = URL(string: "https://weatherstats.app/spread")!
    let parameters = WeatherAPIParams(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, spread: 6, time: Int(date.timeIntervalSince1970))
    let headers: HTTPHeaders = [.authorization(username: Constants.WeatherAPI.username, password: Constants.WeatherAPI.password)]
    return try await AF.request(url, method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default, headers: headers).serializingDecodable(Weather.WeatherSpread.self).value
  }
  
}
