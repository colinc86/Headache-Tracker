//
//  MotionManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import Accelerate
import CoreMotion
import Foundation
import SwiftUI
import Logger

class MotionManager {
  
  // MARK: Types
  
  enum MotionManagerError: Error {
    case userNotPermitted
    case notAvailable
    case cancelled
  }
  
  // MARK: Private properties
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) private var learnAndPredict = false
  
  /// The altimeter.
  private let altimeter = CMAltimeter()
    
  /// The manager's operation queue.
  private lazy var operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  private var updateCount = 0
  
}

// MARK: Static methods

extension MotionManager {
  
  /// The altimeter's authorization status.
  static func authorizationStatus() -> CMAuthorizationStatus {
    return CMAltimeter.authorizationStatus()
  }
  
}

// MARK: Public methods
extension MotionManager {
  
  /// Cancels the current barometric pressure reading.
  func cancelReading() {
    logDebug("Cancel barometer reading.")
    updateCount -= 1
    if updateCount == 0 {
      altimeter.stopRelativeAltitudeUpdates()
    }
  }
  
  /// Gets the current barometric pressure at the device.
  ///
  /// - Parameter completion: Called when the pressure has been fetched.
  func barometricPressure(completion: @escaping (Measurement<UnitPressure>?, Error?) -> Void) {
    logDebug("Get barometric pressure.")
    
    guard learnAndPredict else {
      logWarning("Not learning and predicting.")
      completion(nil, MotionManagerError.userNotPermitted)
      return
    }
    
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      logWarning("Relative altitude not available.")
      completion(nil, MotionManagerError.notAvailable)
      return
    }
    
    updateCount += 1
    altimeter.startRelativeAltitudeUpdates(to: operationQueue) { [weak self] relativeAltitudeData, error in
      if let relativeAltitudeData = relativeAltitudeData {
        logDebug("Got relative altitude data.")
        completion(Measurement(value: relativeAltitudeData.pressure.doubleValue, unit: .kilopascals), error)
      }
      else {
        if let error = error {
          logError("Error getting relative altitude data: \(error)")
        }
        
        completion(nil, error)
      }
      
      self?.updateCount -= 1
      if self?.updateCount == 0 {
        self?.altimeter.stopRelativeAltitudeUpdates()
      }
      logDebug("Finished barometer updates.")
    }
  }
  
}
