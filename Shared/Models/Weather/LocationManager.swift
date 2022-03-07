//
//  LocationManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/23/22.
//

import CoreLocation
import Foundation
import UIKit
import SwiftUI

class LocationManager: NSObject {
  
  // MARK: Types
  
  typealias LocationCompletion = (CLLocation?, Error?) -> Void
  
  /// A location error.
  enum LocationError: Error, CustomStringConvertible {
    case notAvailable
    case notAuthorized
    case cancelled
    case missing
    case deallocated
    
    var description: String {
      switch self {
      case .notAvailable:
        return "Location services are not available on this device."
      case .notAuthorized:
        return "Location services are not authorized."
      case .cancelled:
        return "The reading was cancelled."
      case .missing:
        return "The reading was missing."
      case .deallocated:
        return "The location manager was deallocated."
      }
    }
  }
  
  // MARK: Public properties
  
  /// Whether a widget is authorized for location updates.
  var authorizedForWidgetUpdates: Bool {
    return manager.isAuthorizedForWidgetUpdates
  }
  
  // MARK: Private properties
  
  /// The location manager.
  private let manager = CLLocationManager()
  private var isUpdatingLocation = false
  private var pendingCompletionBlocks = [LocationCompletion]()
  private var pendingCompletionBlocksSemaphore = DispatchSemaphore(value: 1)
  
  // MARK: Initializers
  
  /// Initializes a new location manager.
  override init() {
    super.init()
    manager.delegate = self
  }
  
}

// MARK: Public methods
extension LocationManager {
  
  /// Sets up the location manager for use.
  func setup() {
    if manager.authorizationStatus == .notDetermined {
      manager.requestAlwaysAuthorization()
    }
  }
  
  /// Checks the manager for authorization.
  func checkAuthorization() -> Bool {
    return manager.authorizationStatus != .denied && manager.authorizationStatus != .notDetermined
  }
  
  /// Cancels the current location reading.
  func cancel() {
    logDebug("Cancel location reading.")
    
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    for block in pendingCompletionBlocks {
      block(nil, LocationError.cancelled)
    }
    pendingCompletionBlocks.removeAll()
    
    manager.stopUpdatingLocation()
    isUpdatingLocation = false
  }
  
  /// Gets the device's location from location services.
  ///
  /// - Returns: The device's current location.
  func location() async throws -> CLLocation {
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else {
        continuation.resume(throwing: LocationError.deallocated)
        return
      }
      
      self.location(completion: { location, error in
        if let location = location {
          continuation.resume(returning: location)
        }
        else if let error = error {
          continuation.resume(throwing: error)
        }
        else {
          continuation.resume(throwing: LocationError.missing)
        }
      })
    }
  }
  
}

extension LocationManager {
  
  /// Gets the current location of the device.
  ///
  /// - Parameter completion: Called when the location has been fetched.
  private func location(completion: @escaping (CLLocation?, Error?) -> Void) {
    logDebug("Get location.")
    
    guard CLLocationManager.locationServicesEnabled() else {
      logWarning("Location services not available.")
      completion(nil, LocationError.notAvailable)
      return
    }
    
    guard checkAuthorization() else {
      logWarning("Location services not authorized.")
      completion(nil, LocationError.notAuthorized)
      return
    }
    
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    pendingCompletionBlocks.append(completion)
    
    if !isUpdatingLocation {
      manager.desiredAccuracy = kCLLocationAccuracyKilometer
      manager.startUpdatingLocation()
    }
  }
  
  /// Called when the manager receives a location or an error.
  ///
  /// - Parameters:
  ///   - location: The location.
  ///   - error: The error.
  private func locationUpdate(location: CLLocation?, error: Error?) {
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    if let location = location {
      logDebug("Got location.")
      for completion in pendingCompletionBlocks {
        completion(location, error)
      }
    }
    else {
      for completion in pendingCompletionBlocks {
        completion(nil, error)
      }
    }
    
    pendingCompletionBlocks.removeAll()
    
    manager.stopUpdatingLocation()
    isUpdatingLocation = false
    
    logDebug("Finished location updates.")
  }
  
}

extension LocationManager: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locationUpdate(location: nil, error: error)
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    locationUpdate(location: locations.last, error: nil)
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    
  }
  
}
