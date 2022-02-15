//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import CoreData
import DataController
import Foundation
import HealthKit
import SwiftUI
import Logger

class HeadacheManager: ObservableObject {
  
  // MARK: Weak properties
  
  /// The alert manager to use when adding local notifications.
  weak var alertManager: AlertManager?
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  weak var healthKitManager: HealthKitManager?
  
  /// The headache predictor.
  weak var headachePredictor: HeadachePredictor?
  
  // MARK: Private properties
  
  /// The manager's motion manager.
  private let motionManager = MotionManager()
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The check-in alerts setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The check-in interval setting if `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) private var learnAndPredict = false
  
  /// Whether or not the manager is in test mode. If in test mode, it will not
  /// write to or delete from the health kit store.
  private let testing: Bool
  
  /// The queue to train on.
  private var trainingQueue = DispatchQueue(label: ApplicationKey(from: "trainingQueue"))
  
  // MARK: Initializers
  
  /// Initializes a headache manager.
  ///
  /// - Parameter testing: Set to true for previews.
  init(testing: Bool = false) {
    self.testing = testing
  }
  
}

// MARK: - Current headache methods

extension HeadacheManager {
  
  /// Changes the manager's severity and either creates a new headache, or adds the new
  /// severity to the current headache.
  ///
  /// - Parameters:
  ///   - severity: The headache's current severity.
  ///   - completion: Called after the severity has been added.
  func changeSeverity(to severity: HKCategoryValueSeverity, completion: @escaping (Error?) -> Void) {
    logDebug("Change severity to \(severity.title).")
    
    // The date interval of the severity to save to health kit
    var severityInterval: HealthKitManager.SeverityInterval?
    
    // The headache's identifier to pass to the local notification
    var headacheIdentifier: UUID?
    
    // The identifier of the severity that was added
    var severityIdentifier: UUID?
    
    // Get the current headache
    currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        (severityInterval, severityIdentifier) = headache.addSeverity(severity, startTime: Date())
        headacheIdentifier = headache.identifier
      }
      else {
        logDebug("Creating new headache.")
        let newHeadache = Headache(context: context, initialSeverity: severity, startTime: Date())
        headacheIdentifier = newHeadache.identifier
        severityIdentifier = newHeadache.severitiesArray.first?.identifier
      }
    } completion: { [weak self] error in
      // If there if an error, then we're done
      guard let self = self, !self.testing && error == nil else {
        completion(error)
        return
      }
      
      // Write the data to health kit and set our check-in alert
      self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!]) { saveError in
        self.presentCheckInAlert(with: headacheIdentifier) { checkInError in
          completion(saveError ?? checkInError)
        }
      }
      
      // Update the CoreML models
      if self.learnAndPredict, let severityIdentifier = severityIdentifier {
        self.trainClassifiers(newSeverityIdentifier: severityIdentifier)
      }
    }
  }
  
  /// Resolves the headache.
  ///
  /// - Parameter completion: Called after the headache has resolved.
  func resolve(completion: @escaping (Error?) -> Void) {
    logDebug("Resolve headache.")
    
    // The date interval of the severity to save to health kit
    var severityInterval: HealthKitManager.SeverityInterval?
    
    // Get the current headache
    currentHeadache { headache, context in
      // Resolve the headache
      if let headache = headache {
        severityInterval = headache.resolve(endTime: Date())
      }
      else {
        logWarning("No current headache to resolve.")
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, !self.testing && error == nil else {
        completion(error)
        return
      }
      
      // Cancel any pending notifications
      self.alertManager?.removeRequests(pending: true, delivered: false)
      
      // Write the data to health kit
      self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!], completion: completion)
      
      // Update the CoreML models
      if self.learnAndPredict {
        self.trainClassifiers()
      }
    }
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
      guard let self = self, !self.testing && error == nil else {
        completion(error)
        return
      }
      
      // If there wasn't an error, then we should check and delete it from health kit
      if let startTime = startTime, let endTime = endTime {
        logDebug("Successfully reset headache. Deleting severity samples.")
        self.healthKitManager?.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime), completion: completion)
      }
      else {
        logDebug("Successfully reset headache, but not deleting severity samples.")
      }
    }
  }
  
}

// MARK: - Object management methods

extension HeadacheManager {
  
  /// Adds a new severity to the headache with the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The headache's identifier.
  ///   - completion: The completion block to call after the severity has been added.
  func addSeverityToHeadache(identifier: UUID, completion: @escaping (Error?) -> Void) {
    logDebug("Add severity.")
    
    // The date interval of the severity to save to health kit
    var severityInterval: HealthKitManager.SeverityInterval?
    
    // Get the headache
    headacheWithIdentifier(identifier: identifier) { headache, context in
      if let headache = headache {
        severityInterval = headache.addSeverity(.notPresent, duration: 3600.0)
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, !self.testing && error == nil else {
        completion(error)
        return
      }
      
      self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!], completion: completion)
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
      let request = Headache.fetchRequest(withIdentifier: identifier)
      let headaches = try context.fetch(request)
      if let headache = headaches.first {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
      }
    } completion: { [weak self] error in
      // If there is an error, then we're done
      guard let self = self, !self.testing && error == nil else {
        completion?(error)
        return
      }
      
      // If there wasn't an error, then we should check and delete it from health kit
      if let startTime = startTime, let endTime = endTime {
        logDebug("Successfully reset headache. Deleting severity samples.")
        self.healthKitManager?.deleteSeveritySamples(in: DateInterval(start: startTime, end: endTime), completion: completion)
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
    var newSeveritySamples = [HealthKitManager.SeverityInterval]()
    
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
      guard let self = self, !self.testing && error == nil else {
        completion?(error)
        return
      }
      
      // Check to see if we need to delete and re-add samples
      if let originalHeadacheInterval = originalHeadacheInterval {
        self.healthKitManager?.deleteSeveritySamples(in: originalHeadacheInterval) { error in
          // If there is an error, then we're done
          guard error == nil else {
            completion?(error)
            return
          }
          
          // Otherwise re-add the samples
          self.healthKitManager?.saveSeveritySamples(intervals: newSeveritySamples, completion: completion)
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
    var newSeveritySamples = [HealthKitManager.SeverityInterval]()
    
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
      guard let self = self, !self.testing && error == nil else {
        completion?(error)
        return
      }
      
      // Check to see if we need to delete and re-add samples
      if let originalHeadacheInterval = originalHeadacheInterval {
        self.healthKitManager?.deleteSeveritySamples(in: originalHeadacheInterval) { error in
          // If there is an error, then we're done
          guard error == nil else {
            completion?(error)
            return
          }
          
          // Otherwise re-add the samples
          self.healthKitManager?.saveSeveritySamples(intervals: newSeveritySamples, completion: completion)
        }
      }
    }
  }
  
}

// MARK: - Getting headaches and severities

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
      try update(try context.fetch(request).first, context)
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
      let request = Headache.fetchRequest(withIdentifier: identifier)
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
      let request = Severity.fetchRequest(withIdentifier: identifier)
      try update((try context.fetch(request)).first, context)
    }, completion: completion)
  }
  
}

// MARK: - Alerting

extension HeadacheManager {
  
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
  
}

// MARK: Prediction

extension HeadacheManager {
  
  /// Resets all prediction and learning data.
  func resetPrediction() {
    DataController.shared.performInBackground { context in
      let request = TrainingData.fetchRequest()
      let allTrainingData = try context.fetch(request)
      for trainingData in allTrainingData {
        context.delete(trainingData)
      }
    } completion: { [weak self] error in
      if let error = error {
        logError("Error deleting all training data: \(error)")
      }
      else {
        logDebug("Deleted all training data.")
        self?.headachePredictor?.reset()
      }
    }
  }
  
  /// Whether or not the application needs more not present training data.
  ///
  /// - Returns: A boolean indicating if the app should ask for more training data.
  func needsNotPresentTrainingData(completion: @escaping (Bool) -> Void) {
    var needs = false
    let context = DataController.shared.newNestedBackgroundContext()
    context.perform { [unowned context] in
      let request = TrainingData.fetchRequest()
      let trainingData = (try? context.fetch(request)) ?? []
      let notPresentTrainigData = trainingData.filter({ $0.severity == nil })
      let headacheTrainingDataCount = trainingData.count - notPresentTrainigData.count
      
      var nextHourAllowed = true
      var nextDateAllowed = false
      if let lastNotPresentDate = notPresentTrainigData.last?.timestamp {
        nextHourAllowed = Date().timeIntervalSince(lastNotPresentDate) > 3600.0
        nextDateAllowed = Calendar.current.numberOfDaysBetween(lastNotPresentDate, and: Date()) > 0
      }
      
      needs = (headacheTrainingDataCount >= notPresentTrainigData.count / 2 && nextHourAllowed) || nextDateAllowed
      completion(needs)
    }
  }
  
  /// Gets classifier input appropriate for prediction.
  ///
  /// - Parameter completion: Called when the input struture is ready.
  func getCurrentClassifierInput(_ completion: @escaping (HeadacheClassifierInput?) -> Void) {
    guard !testing else {
      completion(nil)
      return
    }
    
    motionManager.barometricPressure { [weak self] pressure, pressureError in
      guard let self = self else {
        logWarning("Self was nil. Returning early.")
        completion(nil)
        return
      }
      
      if let pressureError = pressureError {
        logError("Error getting barometric pressure: \(pressureError)")
      }
      else if let pressure = pressure {
        logDebug("Got barometric pressure: \(pressure.formatted())")
      }
      let barometricPressure = pressure?.value ?? 0.0
      
      logDebug("Creating input data...")
      let now = Date()
      let interval = DateInterval(start: now.addingTimeInterval(-86400.0), end: now)
      let healthKitData = self.healthKitManager?.readHealthKitData(in: interval) ?? [:]
      completion(HeadacheClassifierInput(barometricPressure: barometricPressure, healthKitData: healthKitData, date: now))
    }
  }
  
  /// Trains the classifiers by creating training data, fetching all training data,
  /// training the classifiers, and then saving/loading them for use.
  ///
  /// - Parameter newSeverityIdentifier: The severity to relate to the new training data.
  ///   Pass `nil` if this training data is for a `notPresent` headche.
  func trainClassifiers(newSeverityIdentifier: UUID? = nil) {
    guard !testing else {
      return
    }
    
    // Get the barometric pressure
    logDebug("Train classifiers. Getting barometric pressure...")
    motionManager.barometricPressure { [weak self] pressure, pressureError in
      guard let self = self else {
        logWarning("Self was nil. Returning early.")
        return
      }
      
      if let pressureError = pressureError {
        logError("Error getting barometric pressure: \(pressureError)")
      }
      else if let pressure = pressure {
        logDebug("Got barometric pressure: \(pressure.formatted())")
      }
      let barometricPressure = pressure?.value ?? 0.0
      
      logDebug("Creating training data...")
      self.trainingQueue.async {
        let context = DataController.shared.newNestedBackgroundContext()
        
        // Create the training data
        let now = Date()
        let interval = DateInterval(start: now.addingTimeInterval(-86400.0), end: now)
        let trainingData = self.learnAndPredict ? TrainingData(context: context, healthKitData: self.healthKitManager?.readHealthKitData(in: interval) ?? [:], barometricPressure: barometricPressure) : nil
        
        logDebug("Created training data.")
        
        if let newSeverityIdentifier = newSeverityIdentifier {
          logDebug("Setting training data on severity \(newSeverityIdentifier)")
          let request = Severity.fetchRequest(withIdentifier: newSeverityIdentifier)
          if let severity = ((try? context.fetch(request)) ?? []).first {
            severity.trainingData = trainingData
          }
          else {
            logWarning("Unable to set training data on severity with identifier: \(newSeverityIdentifier.uuidString)")
          }
        }
        
        logDebug("Saving context.")
        DataController.shared.saveBackgroundAndViewContexts(context) { error in
          if let error = error {
            logError("Error saving training data: \(error)")
          }
          else {
            logDebug("Finished creating training data. Fetching all training data...")
            let request = TrainingData.fetchRequest()
            let allTrainingData = (try? context.fetch(request)) ?? []
            
            logDebug("Training classifiers...")
            self.headachePredictor?.train(with: allTrainingData, completion: { error in
              if let error = error {
                logError("Error training classifiers: \(error)")
              }
              else {
                logDebug("Finished training classifiers.")
              }
            })
          }
        }
      }
    }
  }
  
}
