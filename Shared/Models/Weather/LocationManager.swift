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
  
  // MARK: Private properties
  
  /// The location manager.
  private let manager = CLLocationManager()

  #if DEBUG
  /// Whether the process was launched by the screenshot sweep.
  static let isUITestSeeding = ProcessInfo.processInfo.arguments.contains("--uitest-seed")
  #endif
  private var isUpdatingLocation = false
  private var pendingCompletionBlocks = [LocationCompletion]()
  private var pendingCompletionBlocksSemaphore = DispatchSemaphore(value: 1)

  /// The freshest accurate fix received during the current updating cycle.
  /// Touched only on the main thread (delegate callbacks + timeout).
  private var bestLocation: CLLocation?

  /// Fallback timer so a request never hangs when Core Location can't produce
  /// a recent fix (e.g. indoors). Assigned and cancelled only while holding
  /// `pendingCompletionBlocksSemaphore`, so a resolving cycle can never race
  /// its own timer registration.
  private var timeoutWorkItem: DispatchWorkItem?

  /// A fix older than this (seconds) is treated as a stale cached reading and
  /// not accepted on its own — Core Location delivers the last cached location
  /// first, which may be left over from an earlier (e.g. simulated) session.
  private static let maxFixAge: TimeInterval = 15.0

  /// How long to wait for a recent fix before falling back to the best one
  /// actually received this cycle.
  private static let fixTimeout: TimeInterval = 8.0
  
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
    #if DEBUG
    if LocationManager.isUITestSeeding {
      return
    }
    #endif
    if manager.authorizationStatus == .notDetermined {
      manager.requestAlwaysAuthorization()
    }
  }
  
  /// Checks the manager for authorization.
  ///
  /// Only the two authorized states qualify — `.restricted` (parental controls
  /// / MDM) can't be granted and never produces a fix, so accepting it here
  /// would make every location request wait out the full `fixTimeout` before
  /// falling back to `.missing` instead of failing fast.
  func checkAuthorization() -> Bool {
    return manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
  }
  
  /// Cancels the current location reading.
  func cancel() {
    logDebug("Cancel location reading.")
    
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }

    // Cancel the fallback timer as well. Left scheduled, it outlives this
    // cancelled cycle and can fire during a *later* reading — resolving that
    // reading prematurely (with `.missing` before any fix arrives). This is the
    // orphan-timer hazard the synchronous registration guards against on the
    // fix-resolves-first path; the cancel path has to close it too.
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil

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

    #if DEBUG
    // The screenshot sweep must never touch CoreLocation (the system prompt
    // makes the app non-idle and hangs XCUITest). Return a fixed location.
    if LocationManager.isUITestSeeding {
      completion(CLLocation(latitude: 32.781334, longitude: -96.778609), nil)
      return
    }
    #endif
    
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
      isUpdatingLocation = true
      manager.desiredAccuracy = kCLLocationAccuracyKilometer
      manager.startUpdatingLocation()

      // Don't block a prediction forever if no recent fix arrives; deliver the
      // best fix actually received this cycle after a short wait. Register the
      // work item synchronously within this critical section (not on a deferred
      // main-queue hop) so a fix that resolves the cycle first can always cancel
      // it — a late assignment would otherwise leave an orphan timer that could
      // resolve a *later* cycle prematurely.
      let work = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        self.locationUpdate(location: self.bestLocation, error: self.bestLocation == nil ? LocationError.missing : nil)
      }
      timeoutWorkItem = work
      DispatchQueue.main.asyncAfter(deadline: .now() + LocationManager.fixTimeout, execute: work)
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

    // This cycle is resolving — cancel the fallback timer and reset the fix.
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    bestLocation = nil

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
    // Core Location delivers the last cached fix first, which can be stale
    // (e.g. left over from an earlier simulated location). Track the freshest
    // accurate fix and only resolve once we have a genuinely recent one;
    // otherwise keep waiting until a recent fix arrives or the timeout fires.
    guard let candidate = locations
      .filter({ $0.horizontalAccuracy >= 0 })
      .max(by: { $0.timestamp < $1.timestamp }) else {
      return
    }

    if bestLocation == nil || candidate.timestamp > (bestLocation?.timestamp ?? .distantPast) {
      bestLocation = candidate
    }

    if abs(candidate.timestamp.timeIntervalSinceNow) < LocationManager.maxFixAge {
      locationUpdate(location: candidate, error: nil)
    }
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    
  }
  
}
