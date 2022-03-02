//
//  HealthKitManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import ApplicationKey
import Foundation
import HealthKit
import SwiftUI

class HealthKitManager: ObservableObject {
  
  // MARK: Types
  
  /// A health kit error.
  enum HealthKitError: DescribableError {
    case notAvailable
    case typeNotAvailable
    case unknownAuthorizationStatus(status: HKAuthorizationStatus)
    case authorize
    case save
    case delete
    
    var description: String {
      switch self {
      case .notAvailable:
        return "Health data is not available on this device."
      case .typeNotAvailable:
        return "Health data is not available for the desired type."
      case .unknownAuthorizationStatus(let status):
        return "Unknown authorization status: \(status)"
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
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The manager's health kit store.
  private let store = HKHealthStore()
  
  /// The read queue when gathering training data.
  private let readQueue = DispatchQueue(label: ApplicationKey(from: "readQueue"))
  
  /// The types to share in health kit.
  private let shareTypes: Set<HKSampleType> = Set<HKSampleType>(HealthKitData.allCases.filter({ $0.isShareType }).map({ $0.type! as! HKSampleType }))
  
  /// The types to read in health kit.
  private let readTypes: Set<HKSampleType> = Set<HKSampleType>(HealthKitData.allCases.filter({ !$0.isShareType }).map({ $0.type! as! HKSampleType }))
  
}

extension HealthKitManager {
  
  /// Whether or not the manager needs authorization.
  ///
  /// - Returns: A boolean.
  func needsAuthorization() -> Bool {
    // Is health kit data available?
    guard HKHealthStore.isHealthDataAvailable() else {
      return false
    }
    
    // Do any of our types contain "not determined"?
    return (readTypes.union(shareTypes)).contains(where: { store.authorizationStatus(for: $0) == .notDetermined })
  }
  
  /// Authorizes the manager with health kit.
  ///
  /// - Parameter completion: Called after authorization.
  func authorize(completion: @escaping (Error?) -> Void) {
    if needsAuthorization() {
      logInfo("Authorization status is not determind. Requesting authorization...")
      store.requestAuthorization(toShare: shareTypes, read: readTypes, completion: { success, error in
        if let error = error {
          completion(error)
        }
        else {
          completion(success ? nil : HealthKitError.authorize)
        }
      })
    }
    else if readTypes.contains(where: { type in
      let status = store.authorizationStatus(for: type)
      return status != .sharingAuthorized && status != .sharingDenied
    }) {
      completion(HealthKitError
                  .unknownAuthorizationStatus(
                    status: readTypes
                      .map({ store.authorizationStatus(for: $0) })
                      .first(where: { $0 != .notDetermined && $0 != .sharingDenied && $0 != .sharingAuthorized }) ?? .notDetermined))
    }
    else {
      completion(nil)
    }
  }
  
  /// Saves an array of severity sample.
  ///
  /// - Parameters:
  ///   - intervals: The severity intervals to save.
  ///   - completion: The completion block called after the severity has been added.
  func saveSeveritySamples(intervals: [SeverityInterval], completion: ((Error?) -> Void)? = nil) {
    // Only continue if we have health integration turned on
    guard healthIntegration && !intervals.isEmpty else {
      completion?(nil)
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      completion?(HealthKitError.notAvailable)
      return
    }
    
    // Check our authorization status
    guard store.authorizationStatus(for: headacheType) == .sharingAuthorized else {
      completion?(HealthKitError.typeNotAvailable)
      return
    }
    
    var samples = [HKObject]()
    for interval in intervals {
      samples.append(HKCategorySample(type: headacheType, value: interval.severity.rawValue, start: interval.interval.start, end: interval.interval.end))
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
  func deleteSeveritySamples(in interval: DateInterval, completion: ((Error?) -> Void)?) {
    logDebug("Delete severity samples in \(interval).")
    
    // Only continue if we have health integration turned on
    guard healthIntegration else {
      logWarning("Health integration is \(healthIntegration). Not deleting severity samples.")
      completion?(nil)
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      logWarning("Unable to get headache category type.")
      completion?(HealthKitError.notAvailable)
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
  
  /// Reads health kit training data.
  ///
  /// - Parameter interval: The interval of the data to query.
  /// - Returns: A dictionary of training data.
  func readHealthKitData(in interval: DateInterval) -> [HealthKitData: Double]? {
    logDebug("Read HealthKit data in \(interval).")
    
    // Only continue if we have health integration turned on
    guard healthIntegration else {
      logWarning("Health integration is \(healthIntegration). Not reading HealthKit data.")
      return nil
    }
    
    var healthKitData = [HealthKitData: Double]()
    var didSet = false
    let didSetSemaphore = DispatchSemaphore(value: 1)
    
    let group = DispatchGroup()
    for data in HealthKitData.allCases {
      group.enter()
      readQueue.async {
        guard let query = data.query(in: interval, completion: { query, samples, quantity, error in
          if let samples = samples as? [HKCategorySample] {
            if data.type?.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue {
              var asleepSeconds = samples.filter({ $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue && interval.contains($0.startDate) }).reduce(0.0, { $0 + $1.endDate.timeIntervalSince($1.startDate) })
              if asleepSeconds > 0.0 {
                var sources = [String]()
                for sample in samples {
                  let id = sample.sourceRevision.source.bundleIdentifier
                  if !sources.contains(id) { sources.append(id) }
                }
                asleepSeconds /= sources.count > 0 ? Double(sources.count) : 1.0
              }
              
              didSetSemaphore.wait()
              healthKitData[.sleepAnalysis] = asleepSeconds
              didSet = true
              didSetSemaphore.signal()
            }
            else if data.type?.identifier == HKCategoryTypeIdentifier.mindfulSession.rawValue {
              didSetSemaphore.wait()
              healthKitData[.mindfulSession] = samples.reduce(0.0, { $0 + $1.endDate.timeIntervalSince($1.startDate) })
              didSet = true
              didSetSemaphore.signal()
            }
          }
          else if let quantity = quantity, let unit = data.unit {
            didSetSemaphore.wait()
            healthKitData[data] = quantity.doubleValue(for: unit)
            didSet = true
            didSetSemaphore.signal()
          }
          group.leave()
        }) else {
          group.leave()
          return
        }
        
        self.store.execute(query)
      }
    }

    group.wait()
    
    if didSet {
      return healthKitData
    }
    
    return nil
  }
  
}
