//
//  WeatherManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/25/22.
//

import Foundation
import Logger
import CoreLocation

class WeatherManager {
  
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
    logDebug("Cancel weather manager task.")
    motionManager.cancel()
    locationManager.cancel()
    weatherSpreadTask?.cancel()
  }
  
  /// Gets the current weather of the device.
  ///
  /// Requires:
  /// 1) A barometer is available.
  /// 2) Location services are available.
  /// 3) The network is available.
  ///
  /// - Parameter completion: Called after the weather has been fetched.
  func weather(completion: @escaping (Weather?, Error?) -> Void) {
    logDebug("Get weather...")
    
    motionManager.barometricPressure { [weak self] barometricPressure, bError in
      if let bError = bError {
        completion(nil, bError)
        return
      }
      else if let pressure = barometricPressure {
        self?.locationManager.location(completion: { location, lError in
          if let lError = lError {
            completion(nil, lError)
            return
          }
          else if let location = location {
            self?.getWeatherSpread(location: location, completion: { spread, sError in
              if let sError = sError {
                completion(nil, sError)
                return
              }
              else if let spread = spread {
                completion(Weather(spread: spread, pressure: pressure), nil)
              }
              else {
                completion(nil, nil)
                return
              }
            })
          }
          else {
            completion(nil, nil)
            return
          }
        })
      }
      else {
        completion(nil, nil)
        return
      }
    }
  }
  
}

extension WeatherManager {
  
  /// Gets the weather spread from the weather API.
  ///
  /// - Parameters:
  ///   - location: The location to get the spread for.
  ///   - completion: Called after the spread has been received.
  private func getWeatherSpread(location: CLLocation, completion: @escaping (Weather.WeatherSpread?, Error?) -> Void) {
    let loginString = String(format: "%@:%@", Constants.WeatherAPI.username, Constants.WeatherAPI.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    
    // create the request
    guard let url = URL(string: "https://weatherstats.app/spread?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&spread=6") else {
      completion(nil, nil)
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    
    weatherSpreadTask = URLSession.shared.dataTask(with: request) { data, response, error in
      if let data = data {
        logDebug("Got data: \(data.count) bytes")
        do {
          completion(try JSONDecoder().decode(Weather.WeatherSpread.self, from: data), nil)
        }
        catch let decodingError {
          logDebug("Error decoding response: \(decodingError)")
          completion(nil, decodingError)
        }
      }
      else if let error = error {
        logDebug("Unable to get data: \(error)")
        completion(nil, error)
      }
      else {
        logDebug("Unable to get data or error.")
        completion(nil, nil)
      }
    }
    weatherSpreadTask?.resume()
  }
  
}
