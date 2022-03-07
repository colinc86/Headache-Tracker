//
//  BackgroundTask.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/15/22.
//

import ApplicationKey
import Foundation
import UIKit

class BackgroundTask {
  
  /// The background task's identifier.
  var identifier: String
  
  // MARK: Private properties
  
  /// The task's underlying background task identifier.
  private var taskIdentifier: UIBackgroundTaskIdentifier?
  
  // MARK: Initializers
  
  /// Initializes a background task.
  ///
  /// - Parameter identifier: The task's identifier.
  init(identifier: String) {
    self.identifier = identifier
  }
  
}

// MARK: BackgroundTask

extension BackgroundTask {
  
  /// Begins a new background task.
  ///
  /// - Parameter expired: Called if the task expires. There is no
  ///   need to perform cleanup in this closure. It is handled by the
  ///   background task.
  func begin(expired: (() -> Void)? = nil) {
    logDebug("Begin background task with identifier \(identifier).")
    
    // Capture the old task
    let currentTaskIdentifier = taskIdentifier
    
    // Start the new task
    taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: ApplicationKey(from: identifier), expirationHandler: { [weak self] in
      logDebug("Background task with identifier \(self?.identifier ?? "N/A") expired.")
      expired?()
      self?.end()
    })
    
    // End the old task
    if let currentTaskIdentifier = currentTaskIdentifier, currentTaskIdentifier !=  .invalid {
      logDebug("Ending previous background task with identifier \(identifier).")
      UIApplication.shared.endBackgroundTask(currentTaskIdentifier)
    }
  }
  
  /// Ends the background task.
  func end() {
    logDebug("Ending background task with identifier \(identifier).")
    
    if let taskIdentifier = taskIdentifier, taskIdentifier != .invalid {
      UIApplication.shared.endBackgroundTask(taskIdentifier)
    }
    taskIdentifier = nil
  }
  
}
