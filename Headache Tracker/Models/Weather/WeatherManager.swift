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
  
  private let motionManager = MotionManager()
  private let locationManager = LocationManager()
  private var weatherSpreadTask: URLSessionTask?
  
}

extension WeatherManager {
  
  func setup() {
    logDebug("Setting up weather manager.")
    locationManager.setup()
  }
  
  func cancel() {
    logDebug("Cancel weather manager task.")
    motionManager.cancel()
    locationManager.cancel()
    weatherSpreadTask?.cancel()
  }
  
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
  
  private func getWeatherSpread(location: CLLocation, completion: @escaping (Weather.WeatherSpread?, Error?) -> Void) {
    let username = "f6fad9695be5449475ccfba804ec1018"
    let password = "c4efa0b907f057cdb110d36651e442b3"
    let loginString = String(format: "%@:%@", username, password)
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
