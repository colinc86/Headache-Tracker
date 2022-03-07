//
//  WeatherManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

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
  
  /// The manager's motion manager.
  private let motionManager = MotionManager()
  
  /// The manager's location manager.
  private let locationManager = LocationManager()
  
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
  /// - Returns: The weather.
  func weather() async throws -> Weather {
    logInfo("Get weather.")
    let location = try await locationManager.location()
    let spread = try await getWeatherSpread(location: location)
    let pressure = try await motionManager.barometricPressure()
    return Weather(spread: spread, pressure: pressure)
  }
  
}

extension WeatherManager {
  
  /// Gets the weather spread from the weather API.
  ///
  /// - Parameter location: The location to get the spread for.
  private func getWeatherSpread(location: CLLocation) async throws -> Weather.WeatherSpread {
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else {
        continuation.resume(throwing: WeatherError.deallocated)
        return
      }
      
      let loginString = String(format: "%@:%@", Constants.WeatherAPI.username, Constants.WeatherAPI.password)
      let loginData = loginString.data(using: String.Encoding.utf8)!
      let base64LoginString = loginData.base64EncodedString()
      
      // create the request
      guard let url = URL(string: "https://weatherstats.app/spread?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&spread=6") else {
        continuation.resume(throwing: WeatherError.badRequest)
        return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
      
      self.weatherSpreadTask = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
          logDebug("Got data: \(data.count) bytes")
          do {
            continuation.resume(returning: try JSONDecoder().decode(Weather.WeatherSpread.self, from: data))
          }
          catch let decodingError {
            logDebug("Error decoding response: \(decodingError)")
            continuation.resume(throwing: decodingError)
          }
        }
        else if let error = error {
          logDebug("Unable to get data: \(error)")
          continuation.resume(throwing: error)
        }
        else {
          logDebug("Unable to get data or error.")
          continuation.resume(throwing: WeatherError.missing)
        }
      }
      
      self.weatherSpreadTask?.resume()
    }
  }
  
}
