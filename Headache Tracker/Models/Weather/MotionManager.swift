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
  
  typealias BarometricPressureCompletion = (Measurement<UnitPressure>?, Error?) -> Void
  
  enum MotionError: Error {
    case notAvailable
    case cancelled
  }
  
  // MARK: Private properties
  
  /// The altimeter.
  private let altimeter = CMAltimeter()
  private var isUpdatingPressure = false
  private var pendingCompletionBlocks = [BarometricPressureCompletion]()
  private var pendingCompletionBlocksSemaphore = DispatchSemaphore(value: 1)
    
  /// The manager's operation queue.
  private lazy var operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
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
  func cancel() {
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    logDebug("Cancel barometer reading.")
    
    for block in pendingCompletionBlocks {
      block(nil, MotionError.cancelled)
    }
    pendingCompletionBlocks.removeAll()
    
    altimeter.stopRelativeAltitudeUpdates()
    isUpdatingPressure = false
  }
  
  /// Gets the current barometric pressure at the device.
  ///
  /// - Parameter completion: Called when the pressure has been fetched.
  func barometricPressure(completion: @escaping (Measurement<UnitPressure>?, Error?) -> Void) {
    logDebug("Get barometric pressure.")
    
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      logWarning("Relative altitude not available.")
      completion(nil, MotionError.notAvailable)
      return
    }
    
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    pendingCompletionBlocks.append(completion)
    
    if !isUpdatingPressure {
      isUpdatingPressure = true
      altimeter.startRelativeAltitudeUpdates(to: operationQueue, withHandler: relativeAltitudeUpdate)
    }
  }
  
}

extension MotionManager {
  
  private func relativeAltitudeUpdate(data: CMAltitudeData?, error: Error?) {
    pendingCompletionBlocksSemaphore.wait()
    defer { pendingCompletionBlocksSemaphore.signal() }
    
    if let data = data {
      logDebug("Got relative altitude data.")
      for completion in pendingCompletionBlocks {
        completion(Measurement(value: data.pressure.doubleValue, unit: .kilopascals), error)
      }
    }
    else {
      for completion in pendingCompletionBlocks {
        completion(nil, error)
      }
    }
    
    pendingCompletionBlocks.removeAll()
    
    altimeter.stopRelativeAltitudeUpdates()
    isUpdatingPressure = false
    
    logDebug("Finished barometer updates.")
  }
  
}
