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
  
  enum WeatherError: Error, CustomStringConvertible {
    case badRequest
    case missing
    case deallocated
    
    var description: String {
      switch self {
      case .badRequest:
        return "Bad weather API request."
      case .missing:
        return "The response was missing."
      case .deallocated:
        return "The weather manager was deallocated."
      }
    }
  }
  
  // MARK: Public properties
  
  /// The manager's motion manager.
  let motionManager = MotionManager()
  
  /// The manager's location manager.
  let locationManager = LocationManager()
  
  /// Whether a widget is authorized for location updates.
  var authorizedForWidgetUpdates: Bool {
    return locationManager.authorizedForWidgetUpdates
  }
  
  // MARK: Private properties
  
  /// The manager's weather spread URL task.
  private var weatherSpreadTask: URLSessionTask?
  
}

extension WeatherManager {
  
  /// Sets up the weather manager for use.
  func setup() {
    logDebug("Setting up weather manager.")
    locationManager.setup()
  }
  
  /// Cancels the weather task.
  func cancel() {
    logDebug("Cancel get weather.")
    motionManager.cancel()
    locationManager.cancel()
    weatherSpreadTask?.cancel()
  }
  
  /// Gets the current weather at the device.
  ///
  /// - Parameter date: The date of the weather reading.
  /// - Returns: The weather.
  func weather(date: Date = Date()) async throws -> Weather {
    logInfo("Get weather.")
    
    // Try to get the weather spread
    var spread: Weather.WeatherSpread?
    do {
      let location = try await locationManager.location()
      spread = try await getWeatherSpread(location: location, date: date)
    }
    catch {
      logError("Error getting weather spread: \(error)")
    }
    
    var pressure: Measurement<UnitPressure>?
    do {
      pressure = try await motionManager.barometricPressure()
    }
    catch {
      logError("Error getting pressure: \(error)")
    }
    
    return Weather(spread: spread, pressure: pressure)
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
  private func getWeatherSpread(location: CLLocation, date: Date) async throws -> Weather.WeatherSpread? {
    // create the request
    guard let url = URL(string: "https://weatherstats.app/spread") else {
      return nil
    }
    
    let parameters = WeatherAPIParams(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, spread: 6, time: Int(date.timeIntervalSince1970))
    let headers: HTTPHeaders = [.authorization(username: Constants.WeatherAPI.username, password: Constants.WeatherAPI.password)]
    return try await AF.request(url, method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default, headers: headers).serializingDecodable(Weather.WeatherSpread?.self).value
  }
  
}
