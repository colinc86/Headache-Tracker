//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import BackgroundTasks
import CoreData
import DataController
import Foundation
import HealthKit
import SwiftUI
import WidgetKit

class HeadacheManager: ObservableObject {
  
  // MARK: Weak properties
  
  /// The alert manager to use when adding local notifications.
  weak var alertManager: AlertManager?
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  weak var healthKitManager: HealthKitManager?
  
  /// The manager's weather manager.
  weak var weatherManager: WeatherManager?
  
  /// The headache predictor.
  weak var predictor: Predictor?
  
  // MARK: Private properties
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The check-in alerts setting.
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) private var dailyOutlookAlerts = false
  
  /// The daily outlook alert time.
  @AppStorage(AppSettings.dailyOutlookTime) private var dailyOutlookTime = TimeInterval(28800.0)
  
  /// The check-in interval setting if `checkInAlerts` is true.
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastOutlookDate) private var debugLastOutlookDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextOutlookDate) private var debugNextOutlookDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastTrainingDate) private var debugLastTrainingDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextTrainingDate) private var debugNextTrainingDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.debugLastPredictionDate) private var debugLastPredictionDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.debugNextPredictionDate) private var debugNextPredictionDate: Date?
  
  /// The refresh task responsible for creating background samples.
  private let predictionRefreshTask = RefreshTask(identifier: Constants.Identifiers.backgroundPredictionTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for getting the daily outlook.
  private let outlookRefreshTask = RefreshTask(identifier: Constants.Identifiers.backgroundOutlookTaskIdentifier, type: .appRefresh)
  
  /// The refresh task responsible for re-training the machine learning models.
  private let trainingProcessingTask = RefreshTask(identifier: Constants.Identifiers.backgroundTrainingTaskIdentifier, type: .processing)
  
  /// The create training data background task.
  private var createTrainingDataBackgroundTask = BackgroundTask(identifier: "createTrainingData")
  
  /// The get current classifier input background task.
  private var getCurrentClassifierInputBackgroundTask = BackgroundTask(identifier: "getCurrentClassifierInput")
  
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
    var severityInterval: SeverityInterval?
    
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
      
      // If there wasn't an error, then update the widget data and continue
      SharedUserDefaults.standard.setCurrentSeverity(severity)
      
      // Write the data to health kit and set our check-in alert
      self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!]) { saveError in
        self.presentCheckInAlert(with: headacheIdentifier) { checkInError in
          completion(saveError ?? checkInError)
        }
      }
      
      // Update the CoreML models
      self.createTrainingData(newSeverityIdentifier: severityIdentifier)
    }
  }
  
  /// Resolves the headache.
  ///
  /// - Parameter completion: Called after the headache has resolved.
  func resolve(completion: @escaping (Error?) -> Void) {
    logDebug("Resolve headache.")
    
    // The date interval of the severity to save to health kit
    var severityInterval: SeverityInterval?
    
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
      
      // If there wasn't an error, then update the widget data and continue
      SharedUserDefaults.standard.setCurrentSeverity(nil)
      
      // Cancel any pending notifications
      self.alertManager?.removeRequests(pending: true, delivered: false)
      
      // Write the data to health kit
      self.healthKitManager?.saveSeveritySamples(intervals: severityInterval == nil ? [] : [severityInterval!], completion: completion)
      
      // Update the CoreML models
      self.createTrainingData()
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
      
      // If there wasn't an error, then update the widget data and continue
      SharedUserDefaults.standard.setCurrentSeverity(nil)
      
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
    var severityInterval: SeverityInterval?
    
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
    
    DataController.shared.performInBackground { [weak self] context in
      logDebug("Deleting headache.")
      
      // Get the headache
      let request = Headache.fetchRequest(withIdentifier: identifier)
      let headaches = try context.fetch(request)
      if let headache = headaches.first {
        startTime = headache.startTime
        endTime = headache.endTime ?? headache.pendingEndTime
        context.delete(headache)
        
        // If this headache was the current headache, then cancel any pending check-in notifications
        // and reset the current severity.
        if !headache.resolved {
          self?.alertManager?.removeRequests(pending: true, delivered: false)
          SharedUserDefaults.standard.setCurrentSeverity(nil)
        }
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
  
  /// Presents a prediction alert now.
  ///
  /// - Parameters:
  ///   - prediction: The prediction.
  ///   - completion: Called after the alert has been added to notification center.
  private func presentPredictionAlert(with prediction: Predictor.Prediction?, completion: @escaping (Error?) -> Void) {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard realTimeAlerts, let prediction = prediction, prediction.severityClassifierOutput.prediction != .notPresent && prediction.outlookClassifierOutput.prediction == .headache else {
      completion(nil)
      return
    }
    
    // Make sure we're on the main queue
    DispatchQueue.main.async {
      // Present the alert
      logDebug("Presenting alert for predicted severity: \(prediction.severityClassifierOutput.prediction.title).")
      self.alertManager?.presentAlert(
        with: HeadacheAlertRequest.prediction(severity: prediction.severityClassifierOutput.prediction),
        badgeNumber: 0,
        completion: completion)
    }
  }
  
  /// Presents an outlook alert now.
  ///
  /// - Parameters:
  ///   - prediction: The prediction.
  ///   - completion: Called after the alert has been added to notification center.
  private func presentOutlookAlert(with prediction: Predictor.Prediction?, completion: @escaping (Error?) -> Void) {
    // Only continue if we have a prediction and prediction alerts are turned on
    guard dailyOutlookAlerts, let prediction = prediction else {
      completion(nil)
      return
    }
    
    // Make sure we're on the main queue
    DispatchQueue.main.async {
      // Present the alert
      logDebug("Presenting alert for outlook: \(prediction.outlookClassifierOutput.prediction).")
      self.alertManager?.presentAlert(
        with: HeadacheAlertRequest.outlook(outlook: prediction.outlookClassifierOutput.prediction, onset: prediction.onsetRegressorOutput.prediction),
        badgeNumber: 0,
        completion: completion)
    }
  }
  
}

// MARK: Prediction

extension HeadacheManager {
  
  /// Resets all prediction and learning data.
  func resetPrediction() {
    predictor?.reset()
  }
  
  /// Whether or not the application needs more not present training data.
  ///
  /// - Returns: A boolean indicating if the app should ask for more training data.
  func needsNotPresentTrainingData(completion: @escaping (Bool) -> Void) {
    let context = DataController.shared.newNestedBackgroundContext()
    context.perform { [unowned context] in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      
      let trainingData = (try? context.fetch(request)) ?? []
      let notPresentTrainigData = trainingData.filter({ $0.severity == nil })
      logDebug("Not present training data count: \(notPresentTrainigData.count)")
      
      var nextDateAllowed = false
      if let lastNotPresentDate = notPresentTrainigData.last?.timestamp {
        nextDateAllowed = Date().timeIntervalSince(lastNotPresentDate) > 3600.0 // Every 1 hour
      }
      
      completion(nextDateAllowed)
    }
  }
  
  /// Whether or not the device contains training data that's newer than
  /// the latest compiled models.
  ///
  /// - Parameter completion: Called after the training data has been fetched.
  func needsTraining(completion: @escaping (Bool) -> Void) {
    var needs = false
    let context = DataController.shared.newNestedBackgroundContext()
    context.perform { [unowned context] in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      
      let trainingData = (try? context.fetch(request)) ?? []
      if let date = trainingData.last?.timestamp, let lastTrainingDate = self.predictor?.modelUpdatedAt {
        needs = date.timeIntervalSince(lastTrainingDate) > 0.0
      }
      
      completion(needs)
    }
  }
  
  /// Cancels the current classification input reading.
  func cancelClassificationInput() {
    weatherManager?.cancel()
  }
  
  /// Gets classifier input appropriate for prediction.
  ///
  /// - Parameter completion: Called when the input struture is ready.
  func getCurrentClassifierInput(shouldCreateTrainingData: Bool = false, _ completion: @escaping (Predictor.Input?, Error?) -> Void) {
    guard !testing else {
      completion(nil, nil)
      return
    }
    
    getCurrentClassifierInputBackgroundTask.begin { [weak self] in
      self?.weatherManager?.cancel()
    }
    
    weatherManager?.weather { [weak self] weather, error in
      guard let self = self else {
        logWarning("Self was nil. Returning early.")
        completion(nil, error)
        self?.getCurrentClassifierInputBackgroundTask.end()
        return
      }
      
      if let error = error {
        logError("Error getting weather: \(error)")
        completion(nil, error)
        self.getCurrentClassifierInputBackgroundTask.end()
        return
      }
      else if let weather = weather {
        logDebug("Got weather: \(weather)")
      }
      
      logDebug("Creating input data...")
      let now = Date()
      let interval = DateInterval(start: now.addingTimeInterval(-86400.0), end: now)
      let healthKitData = self.healthKitManager?.readHealthKitData(in: interval)
      
      completion(Predictor.Input(weather: weather, healthKitData: healthKitData, date: now), nil)
      self.getCurrentClassifierInputBackgroundTask.end()
    }
  }
  
  /// Create new training data and sets its `severity` relationship to the severity
  /// with the given identifier. If no identifier is present, then the training data is
  /// still created but orphaned (a not-present severity).
  ///
  /// - Parameters:
  ///   - newSeverityIdentifier: The new severity identifier.
  ///   - completion: The completion block to call after the training data has been created.
  func createTrainingData(newSeverityIdentifier: UUID? = nil, completion: ((Predictor.Input?, Error?) -> Void)? = nil) {
    guard !testing else {
      logDebug("Testing and returning early.")
      completion?(nil, nil)
      return
    }

    logDebug("Create training data background task begin.")
    createTrainingDataBackgroundTask.begin { [weak self] in
      self?.weatherManager?.cancel()
    }

    // Get the barometric pressure
    logDebug("Create training data. Getting input...")
    getCurrentClassifierInput { [weak self] input, error in
      guard let self = self else {
        logWarning("Self was nil. Returning early.")
        self?.createTrainingDataBackgroundTask.end()
        completion?(nil, nil)
        return
      }
      
      if let error = error {
        logError("Error getting weather: \(error)")
        self.createTrainingDataBackgroundTask.end()
        completion?(nil, error)
      }
      else if let input = input {
        logDebug("Got weather: \(input)")

        self.trainingQueue.async {
          let context = DataController.shared.newNestedBackgroundContext()
          
          // Create the training data
          let trainingData = TrainingData(context: context, input: input)
          
          logDebug("Created training data.")
          
          if let newSeverityIdentifier = newSeverityIdentifier {
            logDebug("Setting training data on severity \(newSeverityIdentifier)")
            let request = Severity.fetchRequest(withIdentifier: newSeverityIdentifier)
            if let severity = ((try? context.fetch(request)) ?? []).first {
              severity.addToTrainingData(trainingData)
            }
            else {
              logWarning("Unable to add training data to severity with identifier: \(newSeverityIdentifier.uuidString)")
            }
          }
          
          logDebug("Saving context.")
          DataController.shared.saveBackgroundAndViewContexts(context) { error in
            if let error = error {
              logError("Error saving training data: \(error)")
            }
            else {
              logDebug("Finished saving training data.")
            }
            
            completion?(input, error)
            self.createTrainingDataBackgroundTask.end()
          }
        }
      }
    }
  }
  
  /// Trains the classifiers.
  ///
  /// - Parameter completion: Called when training is complete.
  func trainClassifiers(_ completion: @escaping (Error?) -> Void) {
    guard !testing else {
      return
    }
    
    trainingQueue.async { [weak self] in
      let context = DataController.shared.newNestedBackgroundContext()
      
      logDebug("Fetching all training data...")
      let request = TrainingData.fetchRequest()
      request.predicate = NSPredicate(format: "needsHealthKitData == %@", NSNumber(booleanLiteral: false))
      
      let allTrainingData = (try? context.fetch(request)) ?? []
      
      logDebug("Training classifiers with \(allTrainingData.count) data...")
      self?.predictor?.train(with: allTrainingData, completion: completion)
    }
  }
  
  /// Adds health kit data to incomplete training samples.
  ///
  /// - Parameter completion: Called after the training data has been cleaned.
  func cleanTrainingData(_ completion: @escaping (Error?) -> Void) {
    guard !testing else {
      completion(nil)
      return
    }
    
    logDebug("Cleaning training data.")
    trainingQueue.async { [weak self] in
      let context = DataController.shared.newNestedBackgroundContext()

      logDebug("Fetching incomplete training data...")
      let incompleteRequest = TrainingData.fetchRequest()
      incompleteRequest.predicate = NSPredicate(format: "(needsHealthKitData == %@) || (needsHealthKitData == %@)", NSNumber(booleanLiteral: true), NSNull())
      
      let incompleteTrainingData = (try? context.fetch(incompleteRequest)) ?? []
      
      logDebug("Cleaning \(incompleteTrainingData.count) traininig data...")
      for data in incompleteTrainingData {
        guard let timestamp = data.timestamp else {
          continue
        }
        let interval = DateInterval(start: timestamp.addingTimeInterval(-86400.0), end: timestamp)
        data.updateWithHealthKitData(self?.healthKitManager?.readHealthKitData(in: interval))
      }
      
      DataController.shared.saveBackgroundAndViewContexts(context, completion)
    }
  }
  
}

// MARK: - Predictions background refresh methods

extension HeadacheManager {
  
  /// Sets up the refresh task by registering it.
  func setupPredictionRefreshTask() {
    logDebug("Registering prediction refresh task handler.")
    predictionRefreshTask.register(handlePredictionRefreshTask)
  }
  
  /// Cancels the refresh task.
  func cancelPredictionRefreshTask() {
    logDebug("Cancelling prediction refresh task.")
    predictionRefreshTask.cancel()
  }
  
  /// Schedules the refresh task for the next hour.
  func schedulePredictionRefreshTask() {
    // Get the current seconds past midnight.
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(Date())
    
    // Get the number of seconds past the hour
    let secondsPastHour = secondsPastMidnight - TimeInterval(3600 * Int(floor(secondsPastMidnight / 3600.0)))
    
    // Get the number of seconds until the next hour
    var secondsUntilNextHour = 3600.0 - secondsPastHour
    if secondsPastHour > 3540.0 {
      secondsUntilNextHour += 3600.0
    }
    
    // Schedule the next task
    logDebug("Scheduling prediction refresh task with date \(Date(timeIntervalSinceNow: secondsUntilNextHour))")
    predictionRefreshTask.schedule(interval: secondsUntilNextHour) { [weak self] error in
      if let error = error {
        logError("Unable to schedule prediction task: \(error)")
      }
      else {
        logDebug("Successfully scheduled prediction refresh task.")
        DispatchQueue.main.async {
          self?.debugNextPredictionDate = Date(timeIntervalSinceNow: secondsUntilNextHour)
        }
      }
    }
  }
  
  /// Handles the refresh task.
  private func handlePredictionRefreshTask(_ task: BGTask) {
    logDebug("Handle prediction refresh task.")
    debugLastPredictionDate = Date()
    
    // Schedule the next task
    schedulePredictionRefreshTask()
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.cancelClassificationInput()
    }
    
    // Get the current headache
    var currentSeverityID: UUID?
    
    let context = DataController.shared.newNestedBackgroundContext()
    context.performAndWait { [weak context] in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: false))
      let headache = (try? context?.fetch(request))?.last
      currentSeverityID = headache?.currentSeverity?.identifier
    }
    
    createTrainingData(newSeverityIdentifier: currentSeverityID) { input, error in
      // There's no current headache, so run a prediction
      if let error = error {
        // There was an error with getting the input
        logError("Error getting classifier input: \(error)")
        task.setTaskCompleted(success: false)
      }
      else if let input = input {
        if currentSeverityID == nil {
          // We got the input, so present the prediction
          do {
            let prediction = try self.predictor?.predict(input)
            self.presentPredictionAlert(with: prediction, completion: { error in
              if let error = error {
                logError("Error presenting alert: \(error)")
              }
              task.setTaskCompleted(success: error == nil)
            })
          }
          catch {
            // There was an error predicting
            logError("Error getting prediction: \(error)")
            task.setTaskCompleted(success: false)
          }
        }
        else {
          // We don't need to present a prediction and there was no error
          task.setTaskCompleted(success: true)
        }
      }
      else {
        // Something else went wrong
        task.setTaskCompleted(success: false)
      }
    }
  }
  
}

// MARK: - Daily outlook background refresh methods

extension HeadacheManager {
  
  /// Sets up the refresh task by registering it.
  func setupOutlookRefreshTask() {
    logDebug("Registering outlook refresh task handler.")
    outlookRefreshTask.register(handleOutlookRefreshTask)
  }
  
  /// Cancels the refresh task.
  func cancelOutlookRefreshTask() {
    logDebug("Cancelling outlook refresh task.")
    outlookRefreshTask.cancel()
  }
  
  /// Schedules the outlook task for the daily outlook time.
  func scheduleOutlookRefreshTask() {
    // Get the number of seconds past midnight.
    let now = Date()
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(now)
    
    // Get the number of seconds until the next outlook time
    var secondsUntilOutlook: TimeInterval = 0.0
    
    // Are we past the daily outlook time?
    if secondsPastMidnight < dailyOutlookTime {
      // We haven't passed the outlook time yet.
      secondsUntilOutlook = dailyOutlookTime - secondsPastMidnight
    }
    else {
      // We've already passed the outlook time.
      let futureOutlookDate = Calendar.current.midnightAfter(now).addingTimeInterval(dailyOutlookTime)
      secondsUntilOutlook = futureOutlookDate.timeIntervalSince(now)
    }
    
    // Schedule the outlook task
    logDebug("Scheduling outlook refresh task with date \(Date(timeIntervalSinceNow: secondsUntilOutlook)).")
    outlookRefreshTask.schedule(interval: secondsUntilOutlook) { [weak self] error in
      if let error = error {
        logError("Unable to schedule outlook task: \(error)")
      }
      else {
        logDebug("Successfully scheduled outlook refresh task.")
        DispatchQueue.main.async {
          self?.debugNextOutlookDate = Date(timeIntervalSinceNow: secondsUntilOutlook)
        }
      }
    }
  }
  
  /// Handles the refresh task.
  private func handleOutlookRefreshTask(_ task: BGTask) {
    logDebug("Handle outlook refresh task.")
    debugLastOutlookDate = Date()
    
    // Schedule the next task
    if dailyOutlookAlerts {
      scheduleOutlookRefreshTask()
    }
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak self] in
      // Cancel the prediction
      self?.cancelClassificationInput()
    }
    
    // Run a prediction
    getCurrentClassifierInput { [weak self] input, error in
      if let error = error {
        // There was an error with getting the input
        logError("Error getting classifier input: \(error)")
        task.setTaskCompleted(success: false)
      }
      else if let input = input {
        // We got the input, so present the outlook
        do {
          self?.presentOutlookAlert(with: try self?.predictor?.predict(input), completion: { error in
            if let error = error {
              logError("Error presenting alert: \(error)")
            }
            task.setTaskCompleted(success: error == nil)
          })
        }
        catch {
          // There was an error predicting
          logError("Error getting prediction: \(error)")
          task.setTaskCompleted(success: false)
        }
      }
      else {
        // Something else went wrong
        task.setTaskCompleted(success: false)
      }
    }
  }
  
}

// MARK: Training background processing methods

extension HeadacheManager {
  
  /// Sets up the processing task by registering it.
  func setupTrainingProcessingTask() {
    logDebug("Registering training processing task handler.")
    trainingProcessingTask.register(handleTrainingProcessingTask)
  }
  
  /// Cancels the processing task.
  func cancelTrainingProcessingTask() {
    logDebug("Cancelling training processing task.")
    trainingProcessingTask.cancel()
  }
  
  /// Schedulees the processing task.
  func scheduleTrainingRefreshTask() {
    // Get the number of seconds past midnight.
    let now = Date()
    let secondsPastMidnight = Calendar.current.timeIntervalSinceMidnight(now)
    let dailyTrainingTime: TimeInterval = 60.0 * 60.0 * 5.0
    
    // Get the number of seconds until the next outlook time
    var secondsUntilTraining: TimeInterval = 0.0
    
    // Are we past the daily training time? (5AM)
    if secondsPastMidnight < dailyTrainingTime {
      // We haven't passed the outlook time yet.
      secondsUntilTraining = dailyTrainingTime - secondsPastMidnight
    }
    else {
      // We've already passed the outlook time.
      let futureOutlookDate = Calendar.current.midnightAfter(now).addingTimeInterval(dailyTrainingTime)
      secondsUntilTraining = futureOutlookDate.timeIntervalSince(now)
    }
    
    logDebug("Scheduling training processing task with date \(Date(timeIntervalSinceNow: secondsUntilTraining))")
    trainingProcessingTask.schedule(interval: secondsUntilTraining) { [weak self] error in
      if let error = error {
        logError("Error scheduling training processing task: \(error)")
      }
      else {
        logDebug("Successfully scheduled training procecssing task.")
        DispatchQueue.main.async {
          self?.debugNextTrainingDate = Date(timeIntervalSinceNow: secondsUntilTraining)
        }
      }
    }
  }
  
  /// Handles the processing task.
  private func handleTrainingProcessingTask(_ task: BGTask) {
    logDebug("Handle training processing task.")
    debugLastTrainingDate = Date()
    
    // Schedule the next task
    scheduleTrainingRefreshTask()
    
    // Set the task's expiration handler
    task.expirationHandler = { [weak task, weak self] in
      // Cancel the prediction
      self?.predictor?.cancelTraining()
      task?.setTaskCompleted(success: false)
    }
    
    // Train
    needsTraining { [weak self] needs in
      guard let self = self else {
        task.setTaskCompleted(success: false)
        return
      }
      
      if needs {
        self.trainClassifiers { error in
          if let error = error {
            logError("Error training classifiers: \(error)")
          }
          else {
            logDebug("Successfully trained classifiers.")
          }
          
          task.setTaskCompleted(success: error == nil)
        }
      }
      else {
        task.setTaskCompleted(success: true)
      }
    }
  }
  
}
