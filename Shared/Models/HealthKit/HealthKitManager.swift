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
  
  func authorizationStatus(for data: HealthKitData) -> HKAuthorizationStatus {
    // Is health kit data available?
    guard HKHealthStore.isHealthDataAvailable() else {
      return .sharingDenied
    }
    
    if let type = data.type {
      return store.authorizationStatus(for: type)
    }
    return .notDetermined
  }
  
  func authorize(for data: HealthKitData) async throws {
    guard authorizationStatus(for: data) == .notDetermined else {
      return
    }
    
    if let type = data.type as? HKSampleType {
      if data.isShareType {
        try await store.requestAuthorization(toShare: [type], read: [])
      }
      else {
        try await store.requestAuthorization(toShare: [], read: [type])
      }
    }
  }
  
  /// Authorizes the manager with health kit.
  func authorize() async throws {
    if needsAuthorization() {
      logInfo("Authorization status is not determind. Requesting authorization...")
      try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }
    else if readTypes.contains(where: { type in
      let status = store.authorizationStatus(for: type)
      return status != .sharingAuthorized && status != .sharingDenied
    }) {
      throw HealthKitError
                  .unknownAuthorizationStatus(
                    status: readTypes
                      .map({ store.authorizationStatus(for: $0) })
                      .first(where: { $0 != .notDetermined && $0 != .sharingDenied && $0 != .sharingAuthorized }) ?? .notDetermined)
    }
  }
  
  /// Saves an array of severity sample.
  ///
  /// - Parameter intervals: The severity intervals to save.
  func saveSeveritySamples(intervals: [SeverityInterval]) async throws {
    // Only continue if we have health integration turned on
    guard healthIntegration && !intervals.isEmpty else {
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      throw HealthKitError.notAvailable
    }
    
    // Check our authorization status
    guard store.authorizationStatus(for: headacheType) == .sharingAuthorized else {
      throw HealthKitError.typeNotAvailable
    }
    
    var samples = [HKObject]()
    for interval in intervals {
      samples.append(HKCategorySample(type: headacheType, value: interval.severity.rawValue, start: interval.interval.start, end: interval.interval.end))
    }
    
    try await store.save(samples)
  }
  
  /// Deletes the severity samples in the given date interval.
  ///
  /// - Parameter interval: The interval.
  func deleteSeveritySamples(in interval: DateInterval) async throws {
    logDebug("Delete severity samples in \(interval).")
    
    // Only continue if we have health integration turned on
    guard healthIntegration else {
      logWarning("Health integration is \(healthIntegration). Not deleting severity samples.")
      return
    }
    
    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      logWarning("Unable to get headache category type.")
      throw HealthKitError.notAvailable
    }
    
    // Create our predicate
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
    
    // Delete the objects
    let count = try await store.deleteObjects(of: headacheType, predicate: predicate)
    logDebug("Deleted \(count) severity samples.")
  }
  
  /// Reads health kit training data.
  /// - Parameters:
  ///   - interval: The interval of the data to query.
  ///   - inWidget: Whether this method is being called by a widget.
  /// - Returns: A dictionary of training data.
  func readHealthKitData(in interval: DateInterval, inWidget: Bool = false) -> [HealthKitData: Double]? {
    logDebug("Read HealthKit data in \(interval).")
    
    // Only continue if we have health integration turned on
    guard healthIntegration || inWidget else {
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
            if data == .sleepSeconds {
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
              healthKitData[.sleepSeconds] = asleepSeconds
              didSet = true
              didSetSemaphore.signal()
            }
            else if data == .sleepOnset {
              var onsetSeconds = -1.0
              if let sleepOnset = samples.filter({ $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue && interval.contains($0.startDate) }).min(by: { $0.startDate < $1.startDate })?.startDate {
                onsetSeconds = Calendar.current.timeIntervalSinceMidnight(sleepOnset)
              }
              
              didSetSemaphore.wait()
              healthKitData[.sleepOnset] = onsetSeconds
              didSet = true
              didSetSemaphore.signal()
            }
            else if data == .mindfulSession {
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
