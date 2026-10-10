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
  /// their predictor toggle on. Derived metrics (beat-to-beat HRV) have no
  /// single quantity type, so the heartbeat series type is added explicitly.
  private let readTypes: Set<HKSampleType> = {
    var types = Set<HKSampleType>(HealthKitData.allCases.filter({ !$0.isShareType && !$0.isDeferredAuthorization && !$0.isDerived }).map({ $0.type! as! HKSampleType }))
    types.insert(HKSeriesType.heartbeat())
    return types
  }()
  
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
    // Nothing to authorize when HealthKit isn't available (e.g. iPad) — match
    // the guard in `needsAuthorization()`/`authorizationStatus(for:)`. Without
    // it, `needsAuthorization()` is false (on availability, not determination),
    // so the branch below reads every type as `.notDetermined` and throws a
    // spurious `unknownAuthorizationStatus`.
    guard HKHealthStore.isHealthDataAvailable() else {
      return
    }

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
  ///
  /// - Parameters:
  ///   - date: The end of each metric's sampling window.
  ///   - inWidget: Whether the caller is a widget (skips the expensive
  ///     heartbeat-series read to keep the timeline refresh cheap).
  ///   - only: When set, restricts the read to this metric subset — used by
  ///     the cheaper trailing read that only feeds baseline slopes.
  func readHealthKitData(endingAt date: Date, inWidget: Bool = false, only: Set<HealthKitData>? = nil) -> [HealthKitData: Double]? {
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
    for data in HealthKitData.allCases where !data.isShareType && !data.isDerived && predictorPreferences.isCollectionEnabled(data) && (only?.contains(data) ?? true) {
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

    // Beat-to-beat HRV is computed from a dedicated heartbeat-series read
    // (there's no single HealthKit quantity for it), gated on its own toggle.
    // Skipped for subset reads (the trailing slope read) and in the widget,
    // where the streaming query is too heavy for a timeline refresh.
    if only == nil, !inWidget, predictorPreferences.beatToBeatHRV, let hrv = readHeartbeatSeriesHRV(endingAt: date) {
      for (metric, value) in hrv {
        setValue(metric, value)
      }
    }

    return healthKitData.isEmpty ? nil : healthKitData
  }

  /// Reads trailing fixed-clock-window statistics for every window metric
  /// ending at a date: one `HKStatisticsCollectionQuery` per metric over
  /// hourly buckets anchored to the hour, aggregated the way the metric's
  /// snapshot read aggregates (hourly averages, hourly most-recent, or hourly
  /// sums). Metrics with no samples in the whole window stay absent.
  ///
  /// Synchronous on `readQueue`, like `readHealthKitData`.
  ///
  /// - Parameters:
  ///   - date: The end of the window.
  ///   - only: When set, restricts the read to this metric subset.
  /// - Returns: Statistics per metric, or nil when nothing was read.
  func readWindowStatistics(endingAt date: Date, only: Set<HealthKitData>? = nil) -> [HealthKitData: WindowStatistics]? {
    guard preferences.enabled, predictorPreferences.temporalContext else {
      return nil
    }

    let anchor = WindowStatisticsCalculator.anchor(for: date)
    let start = anchor.addingTimeInterval(-TimeInterval(WindowStatisticsCalculator.bucketCount - 1) * WindowStatisticsCalculator.bucketLength)
    let interval = DateInterval(start: start, end: date)

    var result = [HealthKitData: WindowStatistics]()
    let resultSemaphore = DispatchSemaphore(value: 1)
    let group = DispatchGroup()

    for metric in HealthKitData.windowMetrics where predictorPreferences.isCollectionEnabled(metric) && (only?.contains(metric) ?? true) {
      guard let aggregate = metric.windowAggregate else {
        continue
      }
      group.enter()
      readQueue.async {
        self.hourlySeries(for: metric, in: interval) { series in
          defer { group.leave() }
          guard let series = series, !series.isEmpty else {
            return
          }
          let buckets = WindowStatisticsCalculator.buckets(from: series, endingAt: date)
          if let statistics = WindowStatisticsCalculator.statistics(hourlyBuckets: buckets, aggregate: aggregate) {
            resultSemaphore.wait()
            result[metric] = statistics
            resultSemaphore.signal()
          }
        }
      }
    }

    group.wait()
    return result.isEmpty ? nil : result
  }

  /// Reads a metric's hourly series over an interval, keyed by hour start,
  /// for the training-data back-fill. Synchronous.
  ///
  /// - Parameters:
  ///   - metric: The metric (must be a window metric).
  ///   - interval: The interval to read (callers chunk long spans).
  /// - Returns: The series, or nil when nothing was read.
  func readHourlySeries(for metric: HealthKitData, in interval: DateInterval) -> [Date: Double]? {
    guard preferences.enabled, metric.windowAggregate != nil else {
      return nil
    }

    var result: [Date: Double]?
    let group = DispatchGroup()
    group.enter()
    readQueue.async {
      self.hourlySeries(for: metric, in: interval) { series in
        result = series
        group.leave()
      }
    }
    group.wait()
    return result
  }

  /// Runs a statistics-collection query for a metric over hourly buckets.
  ///
  /// - Parameters:
  ///   - metric: The metric.
  ///   - interval: The interval.
  ///   - completion: Called with the hour-keyed series (nil on failure).
  private func hourlySeries(for metric: HealthKitData, in interval: DateInterval, completion: @escaping ([Date: Double]?) -> Void) {
    guard let identifier = metric.quantityTypeIdentifier,
          let type = HKObjectType.quantityType(forIdentifier: identifier),
          let unit = metric.unit,
          case .statistics(let options) = metric.queryType else {
      completion(nil)
      return
    }

    let anchor = WindowStatisticsCalculator.anchor(for: interval.start)
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: options,
      anchorDate: anchor,
      intervalComponents: DateComponents(hour: 1))

    query.initialResultsHandler = { _, collection, error in
      guard let collection = collection else {
        if let error = error {
          logError("Error reading hourly \(metric): \(error)")
        }
        completion(nil)
        return
      }

      var series = [Date: Double]()
      collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
        let quantity: HKQuantity?
        if options.contains(.cumulativeSum) {
          quantity = statistics.sumQuantity()
        }
        else if options.contains(.discreteAverage) {
          quantity = statistics.averageQuantity()
        }
        else if options.contains(.mostRecent) {
          quantity = statistics.mostRecentQuantity()
        }
        else {
          quantity = nil
        }
        if let quantity = quantity {
          series[statistics.startDate] = quantity.doubleValue(for: unit)
        }
      }
      completion(series)
    }

    store.execute(query)
  }

  /// Reads recent `HKHeartbeatSeriesSample`s and computes beat-to-beat HRV
  /// (RMSSD, pNN50, LF/HF) from their inter-beat intervals.
  ///
  /// Apple never exposes the raw PPG waveform, but it does expose the
  /// beat-to-beat intervals recorded during the Watch's background HRV and
  /// Breathe measurements — the parasympathetic-dominant variability a single
  /// SDNN value throws away. Series are intermittent and discontiguous, so
  /// each is treated as its own segment.
  ///
  /// - Parameter date: The end of the sampling window.
  /// - Returns: The computed HRV metrics, or nil when no usable beats exist.
  func readHeartbeatSeriesHRV(endingAt date: Date) -> [HealthKitData: Double]? {
    guard HKHealthStore.isHealthDataAvailable() else {
      return nil
    }

    let window = HealthKitData.hrvRMSSD.window(endingAt: date)
    let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)

    // Fetch the heartbeat series samples in the window.
    var seriesSamples = [HKHeartbeatSeriesSample]()
    let sampleGroup = DispatchGroup()
    sampleGroup.enter()
    let sampleQuery = HKSampleQuery(sampleType: HKSeriesType.heartbeat(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
      seriesSamples = (samples as? [HKHeartbeatSeriesSample]) ?? []
      sampleGroup.leave()
    }
    store.execute(sampleQuery)
    sampleGroup.wait()

    guard !seriesSamples.isEmpty else {
      return nil
    }

    // Stream each series' beats into an inter-beat-interval segment (ms),
    // skipping intervals flagged as preceded by a gap.
    var segments = [[Double]]()
    let segmentsLock = DispatchSemaphore(value: 1)
    let beatGroup = DispatchGroup()
    for series in seriesSamples {
      beatGroup.enter()
      var intervals = [Double]()
      var lastTime: Double?
      // Guards this series' single balancing `leave()`. HealthKit can deliver a
      // terminal error *without* a `done` callback; without leaving on that
      // path the group would never balance and `beatGroup.wait()` below would
      // hang the read forever. The guard also prevents a double-leave (which
      // would crash) if both an error and a `done` arrive. A single query's
      // handler is invoked serially, so the flag needs no extra locking.
      var finished = false
      let beatQuery = HKHeartbeatSeriesQuery(heartbeatSeries: series) { _, timeSinceSeriesStart, precededByGap, done, error in
        if finished {
          return
        }
        if error != nil {
          finished = true
          beatGroup.leave()
          return
        }
        if !precededByGap, let last = lastTime {
          intervals.append((timeSinceSeriesStart - last) * 1000.0)
        }
        lastTime = timeSinceSeriesStart
        if done {
          finished = true
          segmentsLock.wait()
          segments.append(intervals)
          segmentsLock.signal()
          beatGroup.leave()
        }
      }
      store.execute(beatQuery)
    }
    beatGroup.wait()

    var result = [HealthKitData: Double]()
    if let rmssd = HRVCalculator.rmssd(segments: segments) {
      result[.hrvRMSSD] = rmssd
    }
    if let pnn50 = HRVCalculator.pnn50(segments: segments) {
      result[.hrvPNN50] = pnn50
    }
    if let lfhf = HRVCalculator.lfhf(segments: segments) {
      result[.hrvLFHF] = lfhf
    }
    return result.isEmpty ? nil : result
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
