//
//  Headache+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import Foundation
import HealthKit
import CoreData
import SwiftUI

extension Headache {
  
  /// Gets the headache's severities as a sorted array.
  var severitiesArray: [Severity] {
    return (severities?.sortedArray(using: [NSSortDescriptor(key: "startTime", ascending: true)]) as? [Severity]) ?? []
  }
  
  /// The headache's current severity. If the headache is resolved, this property is nil.
  var currentSeverity: Severity? {
    return resolved ? nil : severitiesArray.last
  }
  
  /// The start time of the first severity in the headache.
  var startTime: Date? {
    return severitiesArray.first?.startTime
  }
  
  /// The end time of the last severity in the headache.
  var endTime: Date? {
    return severitiesArray.last?.endTime
  }
  
  /// The headache's date interval regardless of resolution.
  var dateInterval: DateInterval? {
    guard let startTime = startTime, let endTime = endTime ?? pendingEndTime else {
      return nil
    }
    return DateInterval(start: startTime, end: endTime)
  }
  
  /// The headache's duration in seconds.
  var duration: TimeInterval {
    guard let startTime = startTime else {
      return 0.0
    }
    return (endTime ?? Date()).timeIntervalSince(startTime)
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
  var severityRange: SeverityRange {
    guard let minSeverity = severitiesArray.map({ $0.severity }).min(by: { $0.orderingValue < $1.orderingValue }),
          let maxSeverity = severitiesArray.map({ $0.severity }).max(by: { $0.orderingValue < $1.orderingValue }) else {
            return SeverityRange(lowerBound: .notPresent, upperBound: .notPresent)
          }
    return SeverityRange(lowerBound: minSeverity, upperBound: maxSeverity)
  }
  
  /// The range of colors to use with the headache's severity range.
  var severityColorRange: [Color] {
    let range = severityRange
    var colors = [Color]()
    for i in range.lowerBound.orderingValue ... range.upperBound.orderingValue {
      colors.append((HKCategoryValueSeverity(orderingValue: i) ?? .notPresent).uiColor)
    }
    return colors
  }
  
  /// The headache's severity signal.
  var severitySignal: [HKCategoryValueSeverity] {
    return severitiesArray.map({ $0.severity })
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

// MARK: Static methods

extension Headache {
  
  /// Creates a fetch request
  /// 
  /// - Parameter identifier: The headache's identifier.
  /// - Returns: A fetch request.
  static func fetchRequest(withIdentifier identifier: UUID?) -> NSFetchRequest<Headache> {
    let request = Headache.fetchRequest()
    if let identifier = identifier {
      request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
    }
    return request
  }
  
}

// MARK: Public methods

extension Headache {
  
  /// Reorganizes the headache's severities by start time.
  func reorganize() {
    guard severities?.count ?? 0 > 1 else {
      return
    }
    
    let severities = severitiesArray
    for i in 0 ..< severities.count - 1 {
      severities[i].endTime = severities[i + 1].startTime
    }
  }
  
  /// Adds the severity to the headache.
  ///
  /// - Parameters:
  ///   - severity: The severity.
  ///   - startTime: The severity's start time.
  /// - Returns: A date interval of a completed severity if one's `endTime` was set, and the identifier
  ///   of the newly added Severity.
  @discardableResult
  func addSeverity(_ severity: HKCategoryValueSeverity, startTime: Date) -> (SeverityInterval?, UUID?) {
    logDebug("Adding severity \(severity.title) to the headache.")
    
    // Get the context
    guard let context = managedObjectContext else {
      return (nil, nil)
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
      
      // Add a new open-ended severity
      let newSeverity = Severity(context: context, severity: severity, startTime: startTime)
      addToSeverities(newSeverity)
      
      // Return the updated severity
      return (previousSeverity?.severityInterval, newSeverity.identifier)
    }
    
    return (nil, nil)
  }
  
  /// Adds the severity to the headache with the given duration. Only use this
  /// method with resolved headaches.
  ///
  /// - Parameters:
  ///   - severity: The severity.
  ///   - duration: The severity's duration.
  @discardableResult
  func addSeverity(_ severity: HKCategoryValueSeverity, duration: TimeInterval) -> SeverityInterval? {
    logDebug("Adding severity \(severity.title) with duration \(duration) seconds.")
    
    // Get the context
    guard resolved, let context = managedObjectContext else {
      return nil
    }
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity
    if let previousSeverity = severities.last, let startTime = previousSeverity.endTime {
      // Add a new open-ended severity
      let newSeverity = Severity(context: context, severity: severity, startTime: startTime)
      newSeverity.endTime = startTime.addingTimeInterval(duration)
      addToSeverities(newSeverity)
      return newSeverity.severityInterval
    }
    
    return nil
  }
  
  /// Resolves the headache by setting an end time to the last
  /// severity and setting the headache's `resolved` property
  /// to true.
  ///
  /// - Parameter endTime: The headache's end time.
  func resolve(endTime: Date) -> SeverityInterval? {
    logDebug("Adding severity \(severity.title) to the headache.")
    
    // Resolve the headache
    resolved = true
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity and end it
    if let previousSeverity = severities.last {
      previousSeverity.endTime = endTime
      return previousSeverity.severityInterval
    }
    
    return nil
  }
  
}
