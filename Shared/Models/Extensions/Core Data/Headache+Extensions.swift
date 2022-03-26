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

/// A headache.
extension Headache {
  
  // MARK: Types
  
  /// A headache severity.
  typealias Severity = HKCategoryValueSeverity
  
  /// A headache classification.
  ///
  /// Either primary or secondary.
  enum Classification: String {
    case primary
    case secondary
    
    /// A title suitable for the user interface.
    var title: String {
      return rawValue.capitalized
    }
  }
  
  /// An enumeration of headache types.
  ///
  /// A headache type that is not explicity listed in the enumeration
  /// can be included as a custom type.
  enum Types: Comparable, Hashable, Identifiable, RawRepresentable {
    
    typealias RawValue = String
    
    typealias ObjectIdentifier = String
    
    static var definedCases: [Headache.Types] = [
      .cluster,
      .migraine,
      .tension
    ]
    
    case cluster
    case migraine
    case tension
    case custom(type: String)
    
    var rawValue: String {
      switch self {
      case .custom(let type): return type
      default: return "\(self)"
      }
    }
    
    var id: ObjectIdentifier {
      return rawValue
    }
    
    init(_ rawValue: RawValue) {
      for type in Self.definedCases where type.rawValue == rawValue {
        self = type
        return
      }
      
      if rawValue.isEmpty {
        self = .cluster
      }
      else {
        self = .custom(type: rawValue)
      }
    }
    
    init?(rawValue: RawValue) {
      self.init(rawValue)
    }
    
    /// A title suitable for the user interface.
    var title: String {
      return rawValue.capitalized
    }
  }
  
  /// A structure to track severity updates to a headache.
  struct SeverityUpdates {
    
    /// An empty set of severity updates.
    static let empty = SeverityUpdates(createdSeverityIdentifier: nil, createdSeverityStartTime: nil, updatedSeverityIdentifier: nil, updatedSeverityInterval: nil)
    
    /// The severity that was added to the headache.
    let createdSeverityIdentifier: UUID?
    
    /// The start time of the severity that was created.
    let createdSeverityStartTime: Date?
    
    /// The severity that was updated in the headache.
    let updatedSeverityIdentifier: UUID?
    
    /// The interval of the severity that was updated.
    let updatedSeverityInterval: Severity.Interval?
  }
  
  /// Gets the headache's severities as a sorted array.
  var severitiesArray: [SeverityState] {
    return (severities?.sortedArray(using: [NSSortDescriptor(key: "startTime", ascending: true)]) as? [SeverityState]) ?? []
  }
  
  /// Gets the headache's tags as a sorted array.
  var tagsArray: [Tag] {
    return (tags?.sortedArray(using: [NSSortDescriptor(key: "value", ascending: true)]) as? [Tag]) ?? []
  }
  
  /// Gets the headache's tag values.
  var tagValues: [String] {
    return tagsArray.map({ $0.value ?? "" }).filter({ !$0.isEmpty })
  }
  
  /// The headache's current severity state. If the headache is resolved, this property is nil.
  var currentState: SeverityState? {
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
  var severity: Severity {
    return severitiesArray.last?.severity ?? .notPresent
  }
  
  /// The headache's severity range.
  var severityRange: Severity.Range {
    guard let minSeverity = severitiesArray.map({ $0.severity }).min(by: { $0.orderingValue < $1.orderingValue }),
          let maxSeverity = severitiesArray.map({ $0.severity }).max(by: { $0.orderingValue < $1.orderingValue }) else {
            return Severity.Range(lowerBound: .notPresent, upperBound: .notPresent)
          }
    return Severity.Range(lowerBound: minSeverity, upperBound: maxSeverity)
  }
  
  /// The headache's severity progression.
  var progression: [Severity] {
    return severitiesArray.map({ $0.severity })
  }
  
  /// The headache's classification.
  var headacheClassification: Classification {
    get {
      return Classification(rawValue: classification ?? "") ?? .primary
    }
    
    set {
      classification = newValue.rawValue
    }
  }
  
  /// The headache's type.
  var headacheType: Types {
    get {
      if let type = type {
        return Types(type)
      }
      return .tension // choose the default type
    }
    
    set {
      type = newValue.rawValue
    }
  }
  
  // MARK: Initializers
  
  /// Initializes a headache.
  ///
  /// - Parameters:
  ///   - context: The context to create the headache in.
  ///   - severity: The headache's initial severity. Must not be `not present`.
  ///   - classification: The headache's classification.
  ///   - type: The headache's type.
  ///   - start: The headache's start time.
  ///   - end: The headache's end time.
  convenience init(context: NSManagedObjectContext, severity: Severity, classification: Classification, type: Types, start: Date, end: Date? = nil) {
    self.init(context: context)
    identifier = UUID()
    createdAt = start
    resolved = false
    headacheClassification = classification
    headacheType = type
    addSeverity(severity, start: start, end: end)
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
  
  /// The array of colors to use with the headache's severity range.
  ///
  /// - Parameter scheme: The color scheme.
  /// - Returns: An array of colors.
  func severityColors(for scheme: AppColorScheme) -> [Color] {
    let range = severityRange
    var colors = [Color]()
    for i in range.lowerBound.orderingValue ... range.upperBound.orderingValue {
      colors.append((Severity(orderingValue: i) ?? .notPresent).color(for: scheme))
    }
    return colors
  }
  
  /// Reorganizes the headache's severities by start time.
  func reorganize() {
    guard severities?.count ?? 0 > 1 else {
      return
    }
    
    let severities = severitiesArray
    for i in 0 ..< severities.count - 1 {
      severities[i].endTime = severities[i + 1].startTime
    }
    
    createdAt = severities.first?.startTime
  }
  
  /// Adds the severity to the headache.
  ///
  /// - Parameters:
  ///   - severity: The severity.
  ///   - startTime: The severity's start time.
  ///   - endTime: The severity's end time.
  /// - Returns: Information about the updated and added severities.
  @discardableResult
  func addSeverity(_ severity: Severity, start: Date, end: Date? = nil) -> SeverityUpdates {
    logDebug("Adding severity \(severity.title) to the headache.")
    
    // Get the context
    guard let context = managedObjectContext else {
      return .empty
    }
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity
    let previousSeverity = severities.last
    if previousSeverity?.severity != severity {
      // This is a new severity
      if let previousSeverity = previousSeverity {
        // Set its end time to the new severity's start time
        previousSeverity.endTime = start
      }
      
      // Add a new (possibly open-ended) severity
      let newSeverity = SeverityState(context: context, severity: severity, start: start, end: end)
      
      // If we were given an end time, then mark this headache as resolved
      if end != nil {
        resolved = true
      }
      
      // Add the severity to the headache
      addToSeverities(newSeverity)
      
      // Return the updated severity
      return SeverityUpdates(createdSeverityIdentifier: newSeverity.identifier, createdSeverityStartTime: start, updatedSeverityIdentifier: previousSeverity?.identifier, updatedSeverityInterval: previousSeverity?.severityInterval)
    }
    
    return .empty
  }
  
  /// Adds the severity to the headache with the given duration. Only use this
  /// method with resolved headaches.
  ///
  /// - Parameters:
  ///   - severity: The severity.
  ///   - duration: The severity's duration.
  @discardableResult
  func addSeverity(_ severity: Severity, duration: TimeInterval) -> SeverityUpdates {
    logDebug("Adding severity \(severity.title) with duration \(duration) seconds.")
    
    // Get the context
    guard resolved, let context = managedObjectContext else {
      return .empty
    }
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity
    if let previousSeverity = severities.last, let startTime = previousSeverity.endTime {
      // Add a new open-ended severity
      let newSeverity = SeverityState(context: context, severity: severity, start: startTime, end: startTime.addingTimeInterval(duration))
      addToSeverities(newSeverity)
      return SeverityUpdates(createdSeverityIdentifier: newSeverity.identifier, createdSeverityStartTime: startTime, updatedSeverityIdentifier: previousSeverity.identifier, updatedSeverityInterval: previousSeverity.severityInterval)
    }
    
    return .empty
  }
  
  /// Resolves the headache by setting an end time to the last
  /// severity and setting the headache's `resolved` property
  /// to true.
  ///
  /// - Parameter endTime: The headache's end time.
  func resolve(end: Date) -> SeverityUpdates {
    logDebug("Adding severity \(severity.title) to the headache.")
    
    // Resolve the headache
    resolved = true
    
    // Get the severities
    let severities = severitiesArray
    
    // Get the previous severity and end it
    if let previousSeverity = severities.last {
      previousSeverity.endTime = end
      return SeverityUpdates(createdSeverityIdentifier: nil, createdSeverityStartTime: nil, updatedSeverityIdentifier: previousSeverity.identifier, updatedSeverityInterval: previousSeverity.severityInterval)
    }
    
    return .empty
  }
  
}
