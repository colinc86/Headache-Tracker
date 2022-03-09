//
//  Waiter.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/9/22.
//

import Foundation

class Waiter {
  
  /// The waiter's tolerance in decimal percent. I.e. a tolerance of
  /// 0.1 would apply a tolerance of 10% tos the wait interval.
  var tolerance: Double {
    didSet {
      if tolerance < 0.0 {
        tolerance = 0.0
      }
    }
  }
  
  // MARK: Private properties
  
  /// The timer responsible for ending the wait interval.
  private var timer: Timer?
  
  // MARK: Initializers
  
  /// Initializes a new waiter.
  ///
  /// - Parameters:
  ///   - tolerance: The waiter's tolerance as a decimal percent.
  init(tolerance: Double = 0.1) {
    self.tolerance = tolerance
  }
  
  deinit { stop() }
  
}

// MARK: Public methods

extension Waiter {
  
  /// Waits for the specified interval.
  ///
  /// - Parameters:
  ///   - interval: The interval to wait.
  ///   - repeats: Whether the waiter's block will be fired once or repetitively.
  ///   - mode: The run loop mode.
  ///   - completion: The completion block to call after the waiter is finished waiting.
  func wait(for interval: TimeInterval, repeats: Bool = false, withMode mode: RunLoop.Mode = .default, completion: @escaping () async -> Void) {
    stop()
    
    timer = Timer(timeInterval: interval, repeats: repeats) { _ in
      Task {
        await completion()
      }
    }
    timer?.tolerance = interval * tolerance
    
    if let timer = timer {
      RunLoop.main.add(timer, forMode: mode)
    }
    else {
      Task {
        await completion()
      }
    }
  }
  
  /// Stops waiting.
  func stop() {
    timer?.invalidate()
  }
  
}

