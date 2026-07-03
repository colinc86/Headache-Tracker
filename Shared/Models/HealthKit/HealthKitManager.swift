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
  
  /// The manager's health kit store.
  private let store = HKHealthStore()
  
  /// The health preferences.
  private let preferences = Preferences.Health()

  /// The predictor preferences, gating collection of the opt-in signals.
  private let predictorPreferences = Preferences.Predictors()
  
  /// The read queue when gathering training data.
  private let readQueue = DispatchQueue(label: ApplicationKey(from: "readQueue"))
  
  /// The types to share in health kit.
  private let shareTypes: Set<HKSampleType> = Set<HKSampleType>(HealthKitData.allCases.filter({ $0.isShareType }).map({ $0.type! as! HKSampleType }))

  /// The types to read in health kit.
  ///
  /// Deferred-authorization types (menstrual data) are excluded from the
  /// bulk launch prompt; they're requested individually when the user turns
  /// their predictor toggle on.
  private let readTypes: Set<HKSampleType> = Set<HKSampleType>(HealthKitData.allCases.filter({ !$0.isShareType && !$0.isDeferredAuthorization }).map({ $0.type! as! HKSampleType }))
  
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
  
  /// Gets the authorization status for the specific health kit data.
  ///
  /// - Parameter data: The health kit data.
  /// - Returns: An authorization status.
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
  
  /// Attempts to authorize the given health kit data.
  ///
  /// - Parameter data: The health kit data to authorize.
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
  func saveSeveritySamples(intervals: [Headache.Severity.Interval]) async throws {
    // Only continue if we have health integration turned on
    guard preferences.enabled && !intervals.isEmpty else {
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
    
    // Stamp each sample with its severity's identifier so saves replace
    // prior samples for the same severity and deletes can be scoped to the
    // owning headache instead of everything in a date interval.
    let syncVersion = Int(Date().timeIntervalSince1970)
    var samples = [HKObject]()
    for interval in intervals {
      var metadata: [String: Any]?
      if let identifier = interval.identifier {
        metadata = [
          HKMetadataKeySyncIdentifier: identifier.uuidString,
          HKMetadataKeySyncVersion: syncVersion
        ]
      }
      samples.append(HKCategorySample(type: headacheType, value: interval.severity.rawValue, start: interval.interval.start, end: interval.interval.end, metadata: metadata))
    }

    try await store.save(samples)
  }

  /// Deletes the severity samples in the given date interval.
  ///
  /// - Parameters:
  ///   - interval: The interval.
  ///   - severityIdentifiers: When provided, only this app's samples whose
  ///     sync identifier matches one of these severities (or legacy samples
  ///     without a sync identifier) are deleted. When nil, all of this app's
  ///     headache samples in the interval are deleted.
  func deleteSeveritySamples(in interval: DateInterval, severityIdentifiers: [UUID]? = nil) async throws {
    logDebug("Delete severity samples in \(interval).")

    // Only continue if we have health integration turned on
    guard preferences.enabled else {
      logWarning("Health integration is \(preferences.enabled). Not deleting severity samples.")
      return
    }

    // Get the headache type
    guard let headacheType = HKObjectType.categoryType(forIdentifier: .headache) else {
      logWarning("Unable to get headache category type.")
      throw HealthKitError.notAvailable
    }

    // Create our predicate
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])

    guard let severityIdentifiers = severityIdentifiers else {
      // Delete all of this app's headache samples in the interval.
      let count = try await store.deleteObjects(of: headacheType, predicate: predicate)
      logDebug("Deleted \(count) severity samples.")
      return
    }

    // Fetch the samples in the interval and scope the deletion to the given
    // severities. Legacy samples without a sync identifier can't be
    // attributed to a severity, so they fall back to interval scoping.
    let samples: [HKSample] = try await withCheckedThrowingContinuation { [weak self] continuation in
      let query = HKSampleQuery(sampleType: headacheType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        }
        else {
          continuation.resume(returning: samples ?? [])
        }
      }
      self?.store.execute(query)
    }

    let identifierStrings = Set(severityIdentifiers.map({ $0.uuidString }))
    let samplesToDelete = samples.filter { sample in
      guard let syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String else {
        return true
      }
      return identifierStrings.contains(syncIdentifier)
    }

    guard !samplesToDelete.isEmpty else {
      logDebug("No severity samples to delete.")
      return
    }

    try await store.delete(samplesToDelete)
    logDebug("Deleted \(samplesToDelete.count) severity samples.")
  }
  
  /// Reads health kit training data using each metric's sampling window.
  ///
  /// Only metrics that produced actual samples appear in the returned
  /// dictionary — an absent key means "no reading", which is distinct from a
  /// measured zero.
  ///
  /// - Parameters:
  ///   - date: The end of the sampling windows.
  ///   - inWidget: Whether this method is being called by a widget.
  /// - Returns: A dictionary of training data, or nil when nothing was read.
  func readHealthKitData(endingAt date: Date, inWidget: Bool = false) -> [HealthKitData: Double]? {
    logDebug("Read HealthKit data ending at \(date).")

    // Only continue if we have health integration turned on
    guard preferences.enabled || inWidget else {
      logWarning("Health integration is \(preferences.enabled). Not reading HealthKit data.")
      return nil
    }

    var healthKitData = [HealthKitData: Double]()
    let dataSemaphore = DispatchSemaphore(value: 1)

    let setValue: (HealthKitData, Double) -> Void = { data, value in
      dataSemaphore.wait()
      healthKitData[data] = value
      dataSemaphore.signal()
    }

    let group = DispatchGroup()
    for data in HealthKitData.allCases where !data.isShareType && predictorPreferences.isCollectionEnabled(data) {
      group.enter()
      readQueue.async {
        guard let query = data.query(endingAt: date, completion: { query, samples, quantity, error in
          defer { group.leave() }

          if let samples = samples as? [HKCategorySample] {
            let window = data.window(endingAt: date)
            switch data {
            case .sleepSeconds:
              if let asleepSeconds = HealthKitManager.asleepSeconds(from: samples, in: window) {
                setValue(.sleepSeconds, asleepSeconds)
              }
            case .sleepOnset:
              if let onset = HealthKitManager.sleepOnset(from: samples, in: window) {
                // Carried as a reference-date interval so consumers can
                // reconstruct the full onset Date.
                setValue(.sleepOnset, onset.timeIntervalSinceReferenceDate)
              }
            case .mindfulSession:
              guard !samples.isEmpty else { break }
              setValue(.mindfulSession, samples.reduce(0.0, { $0 + $1.endDate.timeIntervalSince($1.startDate) }))
            case .menstrualFlowActive:
              if let active = HealthKitManager.menstrualFlowActive(from: samples, asOf: date) {
                setValue(.menstrualFlowActive, active ? 1.0 : 0.0)
              }
            case .menstrualDaysSinceCycleStart:
              if let days = HealthKitManager.daysSinceCycleStart(from: samples, asOf: date) {
                setValue(.menstrualDaysSinceCycleStart, days)
              }
            default:
              break
            }
          }
          else if let quantity = quantity, let unit = data.unit {
            setValue(data, quantity.doubleValue(for: unit))
          }
        }) else {
          group.leave()
          return
        }

        self.store.execute(query)
      }
    }

    group.wait()

    return healthKitData.isEmpty ? nil : healthKitData
  }

}

// MARK: Menstrual sample analysis

extension HealthKitManager {

  /// Whether the given menstrual flow sample records actual flow.
  ///
  /// - Parameter sample: The sample.
  /// - Returns: A boolean.
  private static func recordsFlow(_ sample: HKCategorySample) -> Bool {
    // `.none` explicitly records "no flow"; everything else (unspecified,
    // light, medium, heavy) is a flow day.
    return sample.value != HKCategoryValueMenstrualFlow.none.rawValue
  }

  /// Whether menstrual flow was recorded in the trailing 24 hours.
  ///
  /// - Parameters:
  ///   - samples: The menstrual flow samples (60-day window).
  ///   - date: The end of the sampling window.
  /// - Returns: Whether flow is active, or nil when the window contains no
  ///   samples at all — "not tracking" is absent, not zero.
  static func menstrualFlowActive(from samples: [HKCategorySample], asOf date: Date) -> Bool? {
    guard !samples.isEmpty else {
      return nil
    }

    let window = DateInterval(start: date.addingTimeInterval(-86400.0), end: date)
    return samples.contains { sample in
      recordsFlow(sample) && window.intersects(DateInterval(start: sample.startDate, end: sample.endDate))
    }
  }

  /// Days since the most recent cycle start at the given date.
  ///
  /// Prefers samples flagged with `HKMetadataKeyMenstrualCycleStart`;
  /// falls back to the start of the most recent consecutive run of flow
  /// days when a writer omits the metadata.
  ///
  /// - Parameters:
  ///   - samples: The menstrual flow samples (60-day window).
  ///   - date: The date to measure from.
  /// - Returns: Days since cycle start, or nil when no cycle start is found.
  static func daysSinceCycleStart(from samples: [HKCategorySample], asOf date: Date) -> Double? {
    let flowSamples = samples
      .filter({ recordsFlow($0) && $0.startDate <= date })
      .sorted(by: { $0.startDate < $1.startDate })

    guard !flowSamples.isEmpty else {
      return nil
    }

    // Metadata-flagged cycle starts win.
    if let flagged = flowSamples.last(where: { ($0.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) == true }) {
      return date.timeIntervalSince(flagged.startDate) / 86400.0
    }

    // Fallback: walk back from the latest flow day through consecutive days
    // (gaps of more than ~36 hours break the run).
    var runStart = flowSamples.last!
    for sample in flowSamples.dropLast().reversed() {
      if runStart.startDate.timeIntervalSince(sample.endDate) <= 36.0 * 3600.0 {
        runStart = sample
      }
      else {
        break
      }
    }

    return date.timeIntervalSince(runStart.startDate) / 86400.0
  }

}

// MARK: Sleep sample analysis

extension HealthKitManager {

  /// All sleep-analysis raw values that count as asleep, including the
  /// iOS 16+ sleep stages that replaced `asleepUnspecified` on most devices.
  private static let asleepValues: Set<Int> = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map({ $0.rawValue }))

  /// The merged asleep intervals per source, clamped to the window.
  ///
  /// - Parameters:
  ///   - samples: The sleep analysis samples.
  ///   - window: The window to clamp to.
  /// - Returns: Merged asleep intervals keyed by source bundle identifier.
  private static func asleepIntervalsBySource(from samples: [HKCategorySample], in window: DateInterval) -> [String: [DateInterval]] {
    var intervalsBySource = [String: [DateInterval]]()

    for sample in samples where asleepValues.contains(sample.value) {
      guard let overlap = window.intersection(with: DateInterval(start: sample.startDate, end: sample.endDate)), overlap.duration > 0 else {
        continue
      }
      intervalsBySource[sample.sourceRevision.source.bundleIdentifier, default: []].append(overlap)
    }

    // Merge overlapping intervals within each source so stages that overlap
    // (or duplicate records) aren't double counted.
    for (source, intervals) in intervalsBySource {
      let sorted = intervals.sorted(by: { $0.start < $1.start })
      var merged = [DateInterval]()
      for interval in sorted {
        if let last = merged.last, interval.start <= last.end {
          merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
        }
        else {
          merged.append(interval)
        }
      }
      intervalsBySource[source] = merged
    }

    return intervalsBySource
  }

  /// The total asleep seconds in the window, taken from the source with the
  /// most recorded sleep (the watch wins over the phone) rather than
  /// averaging across sources.
  ///
  /// - Parameters:
  ///   - samples: The sleep analysis samples.
  ///   - window: The window to clamp to.
  /// - Returns: Asleep seconds, or nil when no source recorded sleep.
  static func asleepSeconds(from samples: [HKCategorySample], in window: DateInterval) -> Double? {
    let intervalsBySource = asleepIntervalsBySource(from: samples, in: window)
    let totals = intervalsBySource.values.map({ intervals in intervals.reduce(0.0, { $0 + $1.duration }) })
    return totals.max()
  }

  /// The sleep onset in the window from the best source.
  ///
  /// - Parameters:
  ///   - samples: The sleep analysis samples.
  ///   - window: The window to clamp to.
  /// - Returns: The onset date, or nil when no source recorded sleep.
  static func sleepOnset(from samples: [HKCategorySample], in window: DateInterval) -> Date? {
    let intervalsBySource = asleepIntervalsBySource(from: samples, in: window)
    let bestSource = intervalsBySource.max(by: { lhs, rhs in
      lhs.value.reduce(0.0, { $0 + $1.duration }) < rhs.value.reduce(0.0, { $0 + $1.duration })
    })
    return bestSource?.value.first?.start
  }

}
