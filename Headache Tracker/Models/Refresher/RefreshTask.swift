//
//  RefreshTask.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/15/22.
//

import BackgroundTasks
import Foundation

class RefreshTask {
  
  enum RequestType {
    case appRefresh
    case processing
  }
  
  enum RefreshTaskError: DescribableError {
    case alreadyExists(identifier: String)
    case expired(identifier: String)
    
    var description: String {
      switch self {
      case .alreadyExists(let identifier):
        return "A refresh task with the identifier \(identifier) already exists."
      case .expired(let identifier):
        return "The refresh task with identifier \(identifier) expired."
      }
    }
  }
  
  /// The task's identifier.
  var identifier: String
  
  /// The task's type.
  var type: RequestType
  
  // MARK: Initializers
  
  /// Initializes a refresh task.
  ///
  /// - Parameter identifier: The task's identifier.
  init(identifier: String, type: RequestType) {
    self.identifier = identifier
    self.type = type
  }
  
}

// MARK: Public methods

extension RefreshTask {
  
  /// Registers the refresh task for use. This should be called first and once.
  ///
  /// - Parameter launchHandler: The launch handler to call.
  func register(_ launchHandler: @escaping (BGTask) -> Void) {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil, launchHandler: launchHandler)
  }
  
  /// Schedules a task.
  ///
  /// - Parameter date: The date to schedule the task for.
  func schedule(date: Date) async throws {
    let requests = await BGTaskScheduler.shared.pendingTaskRequests()
    
    guard !requests.contains(where: { $0.identifier == self.identifier }) else {
      throw RefreshTaskError.alreadyExists(identifier: self.identifier)
    }
    
    var request: BGTaskRequest!
    if self.type == .appRefresh {
      request = BGAppRefreshTaskRequest(identifier: self.identifier)
      request.earliestBeginDate = date
    }
    else {
      request = BGProcessingTaskRequest(identifier: self.identifier)
      request.earliestBeginDate = date
    }
    
    try BGTaskScheduler.shared.submit(request)
  }
  
  /// Schedules a task.
  ///
  /// - Parameter interval: The interval to schedule the task for.
  func schedule(interval: TimeInterval) async throws {
    try await schedule(date: Date(timeIntervalSinceNow: interval))
  }
  
  /// Cancels the scheduled task.
  func cancel() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
  }
  
}
