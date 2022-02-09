//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
import DataController
import Foundation
import HealthKit
import SwiftUI
import Logger

class HeadacheManager: ObservableObject {
  
  // MARK: Types
  
  typealias SeverityInterval = (HKCategoryValueSeverity, DateInterval)
  typealias SeverityRange = (HKCategoryValueSeverity, HKCategoryValueSeverity)
  
  enum SetupError: DescribableError {
    case notAvailable
    case headacheTypeNotAvailable
    case unknownAuthorizationStatus(status: HKAuthorizationStatus)
    
    var description: String {
      switch self {
      case .notAvailable:
        return "Health data is not available on this device."
      case .headacheTypeNotAvailable:
        return "Headache data is unavailable with HealthKit."
      case .unknownAuthorizationStatus(let status):
        return "Unknown authorization status: \(status)"
      }
    }
  }
  
  enum HealthKitError: DescribableError {
    case authorize
    case save
    case delete
    
    var description: String {
      switch self {
      case .authorize:
        return "Unable to authorize HealthKit."
      case .save:
        return "Unable to save data to HealthKit."
      case .delete:
        return "Unable to delete data from HealthKit."
      }
    }
  }
  
  // MARK: Private properties
  
  /// The alert manager to use when adding local notifications.
  weak var alertManager: AlertManager?
  
  // MARK: Private properties
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The check-in alerts setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The check-in interval setting if `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// Whether or not the manager is in test mode. If in test mode, it will not
  /// write to or delete from the health kit store.
  private let testing: Bool
  
  /// The manager's health kit store.
  private let store = HKHealthStore()
  
  /// The headache type to use with queries and authorizations.
  private lazy var headacheType: HKCategoryType? = {
    if let headacheType = HKObjectType.categoryType(forIdentifier: .headache) {
      return headacheType
    }
    return nil
  }()
  
  // MARK: Initializers
  
  /// Initializes a headache manager.
  ///
  /// - Parameter testing: Set to true for previews.
  init(testing: Bool = false) {
    self.testing = testing
  }
  
}

// MARK: Public methods

extension HeadacheManager {
  
  /// Gets the health kit authorization status.
  ///
  /// - Returns: The current authorization status.
  func authorizationStatus() throws -> HKAuthorizationStatus {
    guard let headacheType = headacheType else {
      throw SetupError.headacheTypeNotAvailable
    }
    return store.authorizationStatus(for: headacheType)
  }
  
  /// Authorizes the manager with health kit.
  ///
  /// - Parameter completion: Called after authorization.
  func authorize(completion: @escaping (Error?) -> Void) {
    // Is health kit data available?
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(SetupError.notAvailable)
      return
    }
    
    // Get the headache type
    guard let headacheType = headacheType else {
      completion(SetupError.headacheTypeNotAvailable)
      return
    }
    
    // Get the status and either authorize or call the callback
    let status = store.authorizationStatus(for: headacheType)
    switch status {
    case .notDetermined:
      logInfo("Authorization status is not determind. Requesting authorization...")
      store.requestAuthorization(toShare: [headacheType], read: [headacheType], completion: { success, error in
        if let error = error {
          completion(error)
        }
        else {
          completion(success ? nil : HealthKitError.authorize)
        }
      })
    case .sharingAuthorized:
      completion(nil)
    case .sharingDenied:
      completion(nil)
    default:
      completion(SetupError.unknownAuthorizationStatus(status: status))
    }
  }
  
  /// Changes the manager's severity and either creates a new headache, or adds the new
  /// severity to the current headache.
  ///
  /// - Parameters:
  ///   - severity: The headache's current severity.
  ///   - completion: Called after the severity has been added.
  func changeSeverity(to severity: HKCategoryValueSeverity, completion: @escaping (Error?) -> Void) {
    logDebug("Change severity to \(severity.title).")
    
    // The date interval of the severity to save to health kit
    var severityInterval: SeverityInterval?
    
    // The headache's identifier to pass to the local notification
    var headacheIdentifier: UUID?
    
    // Get the current headache
    currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        severityInterval = headache.addSeverity(severity, startTime: Date())
        headacheIdentifier = headache.identifier
      }
      else {
        logDebug("Creating new headache.")
        let newHeadache = Headache(context: context, initialSeverity: severity, startTime: Date())
        headacheIdentifier = newHeadache.identifier
      }
    } completion: { [weak self] error in
      // If there if an error, then we're done
      guard let self = self, error == nil else {
        completion(error)
        return
      }
      
      let saveSeverity: (@escaping (Error?) -> Void) -> Void = { block in
        // If there wasn't an error, then we should check and add this to health kit
        if let severityInterval = severityInterval {
          self.saveSeveritySamples(intervals: [severityInterval], completion: block)
        }
        else {
          block(nil)
        }
      }
      
      saveSeverity { saveError in
        self.presentCheckInAlert(with: headacheIdentifier) { checkInError in
          completion(saveError ?? checkInError)
        }
      }
    }
  }
  
  /// Adds a new severity to the headache with the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The headache's identifier.
  ///   - completion: The completion block to call after the severity has been added.
  func addSeverityToHeadache(identifier: UUID, completion: @escaping (Error?) -> Void) {
    logDebug("Add severity.")
    
    // The date interval of the severity to save to health kit
    var severityInterval: SeverityInterval?
    
    // Get the headache
    headacheWithIdentifier(identifier: identifier) { headache, context in
      if let headache = headache {
        severityInterval = headache.addSeverity(.notPresent, duration: 3600.0)
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, error == nil else {
        if let error = error {
          logError("Error deleting severity: \(error)")
        }
        
        completion(error)
        return
      }
      
      if let severityInterval = severityInterval {
        self.saveSeveritySamples(intervals: [severityInterval], completion: completion)
      }
      else {
        completion(nil)
      }
    }
  }
  
  /// Resolves the headache.
  ///
  /// - Parameter completion: Called after the headache has resolved.
  func resolve(completion: @escaping (Error?) -> Void) {
    logDebug("Resolve headache.")
    
    // Get the current headache
    currentHeadache(update: { headache, context in
      if let headache = headache {
        headache.resolve(endTime: Date())
      }
      else {
        logWarning("No current headache to resolve.")
      }
    }, completion: completion)
  }
  
  /// Deletes the current headache.
  ///
  /// - Parameter completion: Called after the headache has been deleted.
  func reset(completion: @escaping (Error?) -> Void) {
    logDebug("Reset headache.")
    
    // The start and end times to delete from health kit
    var startTime: Date?
    var endTime: Date?
    
    // Get the current headache
    currentHeadache { headache, context in
      logDebug("Resetting headache.")
      
      // If we have a current headache, then delete it
      if let headache = headache {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, error == nil else {
        if let error = error {
          logError("Error resetting headache: \(error)")
        }
        
        completion(error)
        return
      }
      
      // If there wasn't an error, then we should check and delete it from health kit
      if let startTime = startTime, let endTime = endTime {
        logDebug("Successfully reset headache. Deleting severity samples.")
        self.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime), completion: completion)
      }
      else {
        logDebug("Successfully reset headache, but not deleting severity samples.")
      }
    }
  }
  
  /// Deletes the headache with the given identifier and it's associated health kit data.
  ///
  /// - Parameters:
  ///   - identifier: The headache's identifier.
  ///   - completion: Called after the headache has been deleted.
  func deleteHeadache(identifier: UUID, completion: ((Error?) -> Void)? = nil) {
    logDebug("Delete headache.")
    
    // The start and end times to delete from health kit
    var startTime: Date?
    var endTime: Date?
    
    DataController.shared.performInBackground { context in
      logDebug("Deleting headache.")
      
      // Get the headache
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
      let headaches = try context.fetch(request)
      if let headache = headaches.first {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, error == nil else {
        if let error = error {
          logError("Error resetting headache: \(error)")
        }
        
        completion?(error)
        return
      }
      
      // If there wasn't an error, then we should check and delete it from health kit
      if let startTime = startTime, let endTime = endTime {
        logDebug("Successfully reset headache. Deleting severity samples.")
        self.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime), completion: completion)
      }
      else {
        logDebug("Successfully reset headache, but not deleting severity samples.")
      }
    }
  }
  
  /// Deletes the severity with the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The severity's identifier.
  ///   - completion: The completion block to call.
  func deleteSeverity(identifier: UUID, completion: ((Error?) -> Void)? = nil) {
    logDebug("Delete severity.")
    
    var originalHeadacheInterval: DateInterval?
    var newSeveritySamples = [SeverityInterval]()
    
    severityWithIdentifier(identifier: identifier) { severity, context in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        headache?.removeFromSeverities(severity)
        context.delete(severity)
        headache?.reorganize()
        
        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, error == nil else {
        if let error = error {
          logError("Error deleting severity: \(error)")
        }
        
        completion?(error)
        return
      }
      
      // Check to see if we need to delete and re-add samples
      if let originalHeadacheInterval = originalHeadacheInterval {
        self.deleteSeveritySamples(in: originalHeadacheInterval) { error in
          // If there is an error, then we're done
          guard error == nil else {
            if let error = error {
              logError("Error deleting severity samples: \(error)")
            }
            
            completion?(error)
            return
          }
          
          // Otherwise re-add the samples
          self.saveSeveritySamples(intervals: newSeveritySamples, completion: completion)
        }
      }
    }
  }
  
  /// Updates the severity with the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The severity's identifier.
  ///   - completion: The completion block to call.
  func updateSeverity(identifier: UUID, value: HKCategoryValueSeverity, startTime: Date, endTime: Date, completion: ((Error?) -> Void)? = nil) {
    logDebug("Update severity.")
    
    var originalHeadacheInterval: DateInterval?
    var newSeveritySamples = [SeverityInterval]()
    
    severityWithIdentifier(identifier: identifier) { severity, context in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        severity.severity = value
        severity.startTime = startTime
        severity.endTime = endTime
        headache?.reorganize()
        
        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, error == nil else {
        if let error = error {
          logError("Error updating severity: \(error)")
        }
        
        completion?(error)
        return
      }
      
      // Check to see if we need to delete and re-add samples
      if let originalHeadacheInterval = originalHeadacheInterval {
        self.deleteSeveritySamples(in: originalHeadacheInterval) { error in
          // If there is an error, then we're done
          guard error == nil else {
            if let error = error {
              logError("Error deleting severity samples: \(error)")
            }
            
            completion?(error)
            return
          }
          
          // Otherwise re-add the samples
          self.saveSeveritySamples(intervals: newSeveritySamples, completion: completion)
        }
      }
    }
  }
  
}

extension HeadacheManager {
  
  /// Gets the current headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameters:
  ///   - update: Called with the current headache to update it. Errors thrown
  ///     in this block will be received in completion.
  ///   - completion: Called after the context has been saved.
  private func currentHeadache(update: @escaping (Headache?, NSManagedObjectContext) throws -> Void, completion: @escaping (Error?) -> Void) {
    DataController.shared.performInBackground(block: { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "ANY severities.endTime = nil")
      try update((try context.fetch(request)).first, context)
    }, completion: completion)
  }
  
  /// Gets the headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameters:
  ///   - update: Called with the headache to update it. Errors thrown
  ///     in this block will be received in completion.
  ///   - completion: Called after the context has been saved.
  private func headacheWithIdentifier(identifier: UUID, update: @escaping (Headache?, NSManagedObjectContext) throws -> Void, completion: @escaping (Error?) -> Void) {
    DataController.shared.performInBackground(block: { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
      try update((try context.fetch(request)).first, context)
    }, completion: completion)
  }
  
  /// Gets the severity and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameters:
  ///   - update: Called with the severity to update it. Errors thrown
  ///     in this block will be received in completion.
  ///   - completion: Called after the context has been saved.
  private func severityWithIdentifier(identifier: UUID, update: @escaping (Severity?, NSManagedObjectContext) throws -> Void, completion: @escaping (Error?) -> Void) {
    DataController.shared.performInBackground(block: { context in
      let request = Severity.fetchRequest()
      request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
      try update((try context.fetch(request)).first, context)
    }, completion: completion)
  }
  
  /// Presents a check-in alert in the future.
  ///
  /// - Parameters:
  ///   - headacheIdentifier: The headache identifier.
  ///   - completion: Called after the alert has been added to notification center.
  private func presentCheckInAlert(with headacheIdentifier: UUID?, completion: @escaping (Error?) -> Void) {
    // Only continue if we have an identifier and check-in alerts are turned on
    guard checkInAlerts, let headacheIdentifier = headacheIdentifier else {
      completion(nil)
      return
    }
    
    // Make sure we're on the main queue
    DispatchQueue.main.async {
      // Cancel any pending notifications
      self.alertManager?.removeRequests(pending: true, delivered: false)
      
      // Get our date components
      let futureDate = Date(timeIntervalSinceNow: self.checkInInterval)
      let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)
      
      // Present the alert
      logDebug("Presenting alert with components at date \(futureDate).")
      self.alertManager?.presentAlert(
        with: HeadacheAlertRequest.checkIn(headacheIdentifier: headacheIdentifier),
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
        badgeNumber: 0,
        completion: completion)
    }
  }
  
  /// Saves an array of severity sample.
  ///
  /// - Parameters:
  ///   - intervals: The severity intervals to save.
  ///   - completion: The completion block called after the severity has been added.
  private func saveSeveritySamples(intervals: [SeverityInterval], completion: ((Error?) -> Void)? = nil) {
    // Only continue if we have health integration turned on
    guard !testing && healthIntegration else {
      completion?(nil)
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      completion?(SetupError.notAvailable)
      return
    }
    
    // Check our authorization status
    guard store.authorizationStatus(for: headacheType) == .sharingAuthorized else {
      completion?(SetupError.headacheTypeNotAvailable)
      return
    }
    
    var samples = [HKObject]()
    for interval in intervals {
      samples.append(HKCategorySample(type: headacheType, value: interval.0.rawValue, start: interval.1.start, end: interval.1.end))
    }
    
    store.save(samples) { (success, error) in
      if let error = error {
        completion?(error)
      } else {
        completion?(success ? nil : HealthKitError.save)
      }
    }
  }
  
  /// Deletes the severity samples in the given date interval.
  ///
  /// - Parameters:
  ///   - interval: The interval.
  ///   - completion: Called after samples have been deleted.
  private func deleteSeveritySamples(in interval: DateInterval, completion: ((Error?) -> Void)?) {
    logDebug("Delete severity samples in \(interval).")
    
    // Only continue if we have health integration turned on
    guard !testing && healthIntegration else {
      logWarning("Testing is \(testing) and health integration is \(healthIntegration). Not deleting severity samples.")
      completion?(nil)
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      logWarning("Unable to get headache category type.")
      completion?(SetupError.notAvailable)
      return
    }
    
    // Create our predicate
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
    
    // Delete the objects
    store.deleteObjects(of: headacheType, predicate: predicate) { success, count, error in
      if let error = error {
        logError("Error deleting severity samples: \(error)")
        completion?(error)
      }
      else {
        if success {
          logDebug("Deleted \(count) severity samples.")
        }
        else {
          logWarning("Unable to delete severity samples.")
        }
        completion?(success ? nil : HealthKitError.delete)
      }
    }
  }
  
}
