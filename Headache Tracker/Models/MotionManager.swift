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
  
  enum MotionManagerError: Error {
    case userNotPermitted
    case notAvailable
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
  
  /// Gets the current barometric pressure at the device.
  ///
  /// - Parameter completion: Called when the pressure has been fetched.
  func barometricPressure(completion: @escaping (Measurement<UnitPressure>?, Error?) -> Void) {
    guard learnAndPredict else {
      completion(nil, MotionManagerError.userNotPermitted)
      return
    }
    
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      completion(nil, MotionManagerError.notAvailable)
      return
    }
    
    altimeter.startRelativeAltitudeUpdates(to: operationQueue) { [weak self] relativeAltitudeData, error in
      if let relativeAltitudeData = relativeAltitudeData {
        completion(Measurement(value: relativeAltitudeData.pressure.doubleValue, unit: .kilopascals), error)
      }
      else {
        completion(nil, error)
      }
      
      self?.altimeter.stopRelativeAltitudeUpdates()
    }
  }
  
}
