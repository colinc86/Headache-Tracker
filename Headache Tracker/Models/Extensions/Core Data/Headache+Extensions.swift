//
//  Headache+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import Foundation
import HealthKit
import CoreData
import Logger

extension Headache {
  
  /// Gets the headache's severities as a sorted array.
  var severitiesArray: [Severity] {
    return (severities?.sortedArray(using: [NSSortDescriptor(key: "startTime", ascending: true)]) as? [Severity]) ?? []
  }
  
  /// The start time of the first severity in the headache.
  var startTime: Date? {
    return severitiesArray.first?.startTime
  }
  
  /// The end time of the last severity in the headache.
  var endTime: Date? {
    return severitiesArray.last?.endTime
  }
  
  /// The headache's duration in seconds.
  var duration: TimeInterval {
    guard let startTime = startTime else {
      return 0.0
    }
    return (endTime ?? Date()).timeIntervalSince(startTime)
  }
  
  /// A textual description of the severity.
  var severityDescription: String {
    guard let minSeverity = severitiesArray.map({ $0.severity }).min(by: { $0.orderingValue < $1.orderingValue }),
          let maxSeverity = severitiesArray.map({ $0.severity }).max(by: { $0.orderingValue < $1.orderingValue }) else {
            return HKCategoryValueSeverity.notPresent.title
          }
    
    if minSeverity != maxSeverity {
      return "\(minSeverity.title) - \(maxSeverity.title)"
    }
    
    return minSeverity.title
  }
  
  /// The start time of the last severity _if it's `endTime` is `nil`_.
  var pendingEndTime: Date? {
    let last = severitiesArray.last
    return last?.endTime == nil ? last?.startTime : nil
  }
  
  /// The value of the last severity.
  var severity: HKCategoryValueSeverity {
    return severitiesArray.last?.severity ?? .notPresent
  }
  
  /// The headache's severity range.
  var severityRange: HeadacheManager.SeverityRange {
    guard let minSeverity = severitiesArray.map({ $0.severity }).min(by: { $0.orderingValue < $1.orderingValue }),
          let maxSeverity = severitiesArray.map({ $0.severity }).max(by: { $0.orderingValue < $1.orderingValue }) else {
            return (.notPresent, .notPresent)
          }
    return (minSeverity, maxSeverity)
  }
  
  // MARK: Initializers
  
  /// Initializes a headache.
  ///
  /// - Parameters:
  ///   - context: The context to create the headache in.
  ///   - initialSeverity: The headache's initial severity. Must not be `not present`.
  ///   - startTime: The headache's start time.
  convenience init(context: NSManagedObjectContext, initialSeverity: HKCategoryValueSeverity, startTime: Date) {
    self.init(context: context)
    identifier = UUID()
    createdAt = Date()
    resolved = false
    addSeverity(initialSeverity, startTime: startTime)
  }
  
}

extension Headache {
  
  /// Adds the severity to the headache.
  ///
  /// - Parameters:
  ///   - severity: The severity.
  ///   - startTime: The severity's start time.
  /// - Returns: A date interval of a completed severity if one's `endTime` was set.
  @discardableResult
  func addSeverity(_ severity: HKCategoryValueSeverity, startTime: Date) -> HeadacheManager.SeverityInterval? {
    logDebug("Adding severity \(severity.title) to the headache.")
    
    // Get the context
    guard let context = managedObjectContext else {
      return nil
    }
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity
    let previousSeverity = severities.last
    if previousSeverity?.severity != severity {
      // This is a new severity
      if let previousSeverity = previousSeverity {
        // Set its end time to the new severity's start time
        previousSeverity.endTime = startTime
      }
      
      // Add a new open-ended severity if it's not "not present"
      if severity == .notPresent {
        // This headache has resolved
        resolved = true
      }
      else {
        let newSeverity = Severity(context: context, severity: severity, startTime: startTime)
        addToSeverities(newSeverity)
      }
      
      // Return the updated severity
      return previousSeverity?.severityInterval
    }
    
    return nil
  }
  
}
