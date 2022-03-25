//
//  SeverityState+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import CoreData
import Foundation

extension SeverityState {
  
  // MARK: Properties
  
  /// The severity's health kit severity value.
  var severity: Headache.Severity {
    get { return Headache.Severity(rawValue: Int(rawValue)) ?? .notPresent }
    set { rawValue = Int64(newValue.rawValue) }
  }
  
  /// The severity's severity interval.
  var severityInterval: Headache.Severity.Interval? {
    guard let startTime = startTime, let endTime = endTime else {
      return nil
    }
    return  Headache.Severity.Interval(severity, start: startTime, end: endTime)
  }
  
  /// The severity's training data as an array.
  var trainingDataArray: [TrainingData] {
    return (trainingData?.sortedArray(using: [NSSortDescriptor(key: "timestamp", ascending: true)]) as? [TrainingData]) ?? []
  }
  
  // MARK: Initializers
  
  /// Initializes a severity.
  ///
  /// - Parameters:
  ///   - context: The context to create the severity in.
  ///   - initialSeverity: The severity.
  ///   - startTime: The severity's start time.
  ///   - endTime: The severity's end time.
  convenience init(context: NSManagedObjectContext, severity: Headache.Severity, start: Date, end: Date?) {
    self.init(context: context)
    self.severity = severity
    self.startTime = start
    self.endTime = end
    self.identifier = UUID()
  }
  
}

// MARK: Static methods

extension SeverityState {
  
  /// Creates a fetch request
  ///
  /// - Parameter identifier: The severity's identifier.
  /// - Returns: A fetch request.
  static func fetchRequest(withIdentifier identifier: UUID?) -> NSFetchRequest<SeverityState> {
    let request = SeverityState.fetchRequest()
    if let identifier = identifier {
      request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
    }
    return request
  }
  
}
