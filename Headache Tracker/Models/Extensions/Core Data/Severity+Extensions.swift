//
//  Severity+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import CoreData
import Foundation
import HealthKit

extension Severity {
  
  // MARK: Properties
  
  /// The severity's health kit severity value.
  var severity: HKCategoryValueSeverity {
    get { return HKCategoryValueSeverity(rawValue: Int(rawValue)) ?? .notPresent }
    set { rawValue = Int64(newValue.rawValue) }
  }
  
  /// The severity's severity interval.
  var severityInterval: HeadacheManager.SeverityInterval? {
    guard let startTime = startTime, let endTime = endTime else {
      return nil
    }
    return (severity, DateInterval(start: startTime, end: endTime))
  }
  
  // MARK: Initializers
  
  /// Initializes a severity.
  ///
  /// - Parameters:
  ///   - context: The context to create the severity in.
  ///   - initialSeverity: The severity.
  ///   - startTime: The severity's start time.
  convenience init(context: NSManagedObjectContext, severity: HKCategoryValueSeverity, startTime: Date) {
    self.init(context: context)
    self.severity = severity
    self.startTime = startTime
    self.identifier = UUID()
  }
  
}
