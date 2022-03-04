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

class MotionManager {
  
  // MARK: Types
  
  typealias BarometricPressureCompletion = (Measurement<UnitPressure>?, Error?) -> Void
  
  /// A barometric pressure error.
  enum MotionError: Error, CustomStringConvertible {
    case notAvailable
    case cancelled
    case missing
    case deallocated
    
    var description: String {
      switch self {
      case .notAvailable:
        return "Barometric pressure is not available on this device."
      case .cancelled:
        return "The reading was cancelled."
      case .missing:
        return "The reading was missing."
      case .deallocated:
        return "The motion manager was deallocated."
      }
    }
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
  
  /// Gets the barometric pressure read by the device.
  ///
  /// - Returns: The current barometric pressure.
  func barometricPressure() async throws -> Measurement<UnitPressure> {
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self = self else {
        continuation.resume(throwing: MotionError.deallocated)
        return
      }
      
      self.barometricPressure { measurement, error in
        if let measurement = measurement {
          continuation.resume(returning: measurement)
        }
        else if let error = error {
          continuation.resume(throwing: error)
        }
        else {
          continuation.resume(throwing: MotionError.missing)
        }
      }
    }
  }
  
}

extension MotionManager {
  
  /// Gets the current barometric pressure at the device.
  ///
  /// - Parameter completion: Called when the pressure has been fetched.
  private func barometricPressure(completion: @escaping (Measurement<UnitPressure>?, Error?) -> Void) {
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
  
  /// Called when the relative altitude is updated.
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
