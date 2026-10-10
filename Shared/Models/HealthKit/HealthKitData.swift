//
//  HealthKitData.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import Foundation
import HealthKit

/// A HealthKit data type.
enum HealthKitDataType {
  case category
  case quantity
}

/// A HealthKit query type.
enum HealthKitDataQueryType {
  case sample
  case statistics(options: HKStatisticsOptions)
}

/// HealthKit data.
enum HealthKitData: CaseIterable, Codable {
  case headache
  case sleepSeconds
  case sleepOnset
  case mindfulSession
  case stepCount
  case environmentalAudioExposure
  case headphoneAudioExposure
  case heartRate
  case restingHeartRate
  case walkingHeartRateAverage
  case heartRateVariabilitySDNN
  case oxygenSaturation
  case respiratoryRate
  case dietaryCaffeine
  case dietaryWater
  case timeInDaylight
  case appleExerciseTime
  case menstrualDaysSinceCycleStart
  case menstrualFlowActive
  case bodyTemperature
  case wristTemperature
  case basalBodyTemperature
  case hrvRMSSD
  case hrvPNN50
  case hrvLFHF

  /// Whether or not this is a sharable type.
  var isShareType: Bool {
    switch self {
    case .headache: return true
    default: return false
    }
  }

  /// Whether this metric is computed on-device from a dedicated read path
  /// (beat-to-beat HRV from `HKHeartbeatSeriesSample`) rather than mapping to
  /// a single HealthKit quantity/category type. Derived metrics have no
  /// `type` and are excluded from the generic read loop and authorization set.
  var isDerived: Bool {
    switch self {
    case .hrvRMSSD, .hrvPNN50, .hrvLFHF: return true
    default: return false
    }
  }

  /// Whether authorization for this type should be deferred to an explicit
  /// user opt-in instead of the bulk launch-time prompt. Used for sensitive
  /// types like menstrual data.
  var isDeferredAuthorization: Bool {
    switch self {
    case .menstrualDaysSinceCycleStart, .menstrualFlowActive: return true
    default: return false
    }
  }

  /// The data's type.
  var dataType: HealthKitDataType {
    switch self {
    case .headache, .sleepSeconds, .sleepOnset, .mindfulSession, .menstrualDaysSinceCycleStart, .menstrualFlowActive:
      return .category
    default:
      return .quantity
    }
  }

  /// The data's category type identifier.
  var categoryTypeIdentifier: HKCategoryTypeIdentifier? {
    switch self {
    case .headache: return .headache
    case .sleepSeconds, .sleepOnset: return .sleepAnalysis
    case .mindfulSession: return .mindfulSession
    case .menstrualDaysSinceCycleStart, .menstrualFlowActive: return .menstrualFlow
    default: return nil
    }
  }

  /// The data's quantitity type identifier.
  var quantityTypeIdentifier: HKQuantityTypeIdentifier? {
    switch self {
    case .stepCount: return .stepCount
    case .environmentalAudioExposure: return .environmentalAudioExposure
    case .headphoneAudioExposure: return .headphoneAudioExposure
    case .heartRate: return .heartRate
    case .restingHeartRate: return .restingHeartRate
    case .walkingHeartRateAverage: return .walkingHeartRateAverage
    case .heartRateVariabilitySDNN: return .heartRateVariabilitySDNN
    case .oxygenSaturation: return .oxygenSaturation
    case .respiratoryRate: return .respiratoryRate
    case .dietaryCaffeine: return .dietaryCaffeine
    case .dietaryWater: return .dietaryWater
    case .timeInDaylight: return .timeInDaylight
    case .appleExerciseTime: return .appleExerciseTime
    case .bodyTemperature: return .bodyTemperature
    case .wristTemperature: return .appleSleepingWristTemperature
    case .basalBodyTemperature: return .basalBodyTemperature
    default: return nil
    }
  }

  /// The data's unit.
  var unit: HKUnit? {
    switch self {
    case .stepCount: return .count()
    case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .respiratoryRate: return .count().unitDivided(by: .minute())
    case .environmentalAudioExposure, .headphoneAudioExposure: return .decibelAWeightedSoundPressureLevel()
    case .heartRateVariabilitySDNN: return .secondUnit(with: .milli)
    case .oxygenSaturation: return .percent()
    case .dietaryCaffeine: return .gramUnit(with: .milli)
    case .dietaryWater: return .literUnit(with: .milli)
    case .timeInDaylight, .appleExerciseTime: return .minute()
    case .bodyTemperature, .wristTemperature, .basalBodyTemperature: return .degreeCelsius()
    default: return nil
    }
  }

  /// The sampling window to read for this metric, ending at the given date.
  ///
  /// Fast-moving metrics use short trailing windows; sleep uses the previous
  /// evening onward; daily aggregates look back far enough to contain at
  /// least one sample.
  ///
  /// The metrics that get trailing-window context (24h mean/delta, 48h and
  /// 72h range, 6h delta), in stable order. Excluded: the menstrual metrics
  /// (categorical, 60-day), mindful sessions (sparse and user-controlled),
  /// sleep (one value per night, already baseline-relative), the derived HRV
  /// metrics (would need bucketed heartbeat-series reads), and the
  /// correlation-only metrics that feed no model column.
  static let windowMetrics: [HealthKitData] = [
    .heartRate,
    .heartRateVariabilitySDNN,
    .respiratoryRate,
    .oxygenSaturation,
    .bodyTemperature,
    .environmentalAudioExposure,
    .headphoneAudioExposure,
    .restingHeartRate,
    .walkingHeartRateAverage,
    .wristTemperature,
    .basalBodyTemperature,
    .stepCount
  ]

  /// How this metric's hourly buckets are aggregated for window context, or
  /// nil when the metric gets none.
  var windowAggregate: WindowAggregate? {
    switch self {
    case .heartRate, .heartRateVariabilitySDNN, .respiratoryRate, .oxygenSaturation, .bodyTemperature,
        .environmentalAudioExposure, .headphoneAudioExposure:
      return .discreteAverage
    case .restingHeartRate, .walkingHeartRateAverage, .wristTemperature, .basalBodyTemperature:
      return .mostRecent
    case .stepCount:
      return .cumulativeSum
    default:
      return nil
    }
  }

  /// The base of this metric's `ContextData` attribute names (e.g.
  /// `heartRateMean24h`), or nil when the metric gets no window context.
  var contextAttributeBase: String? {
    switch self {
    case .heartRate: return "heartRate"
    case .heartRateVariabilitySDNN: return "heartRateVariability"
    case .respiratoryRate: return "respiratoryRate"
    case .oxygenSaturation: return "oxygenSaturation"
    case .bodyTemperature: return "bodyTemperature"
    case .environmentalAudioExposure: return "environmentalAudioExposure"
    case .headphoneAudioExposure: return "headphoneAudioExposure"
    case .restingHeartRate: return "restingHeartRate"
    case .walkingHeartRateAverage: return "walkingHeartRateAverage"
    case .wristTemperature: return "wristTemperature"
    case .basalBodyTemperature: return "basalBodyTemperature"
    case .stepCount: return "stepCount"
    default: return nil
    }
  }

  /// - Parameter date: The end of the window.
  /// - Returns: The window to query.
  func window(endingAt date: Date) -> DateInterval {
    switch self {
    case .sleepSeconds, .sleepOnset:
      // 6 PM the previous day through now.
      let start = Calendar.current.startOfDay(for: date).addingTimeInterval(-6.0 * 3600.0)
      return DateInterval(start: min(start, date), end: date)
    case .heartRate:
      return DateInterval(start: date.addingTimeInterval(-3600.0), end: date)
    case .restingHeartRate, .walkingHeartRateAverage, .wristTemperature, .basalBodyTemperature:
      // Wrist and basal temperature are written roughly once per night;
      // look back far enough to contain the most recent reading.
      return DateInterval(start: date.addingTimeInterval(-48.0 * 3600.0), end: date)
    case .menstrualDaysSinceCycleStart, .menstrualFlowActive:
      // Long enough to contain the most recent cycle start.
      return DateInterval(start: date.addingTimeInterval(-60.0 * 86400.0), end: date)
    default:
      return DateInterval(start: date.addingTimeInterval(-86400.0), end: date)
    }
  }
  
  /// The data's health kit object type.
  var type: HKObjectType? {
    switch dataType {
    case .category:
      guard let categoryTypeIdentifier = categoryTypeIdentifier else {
        return nil
      }
      return HKObjectType.categoryType(forIdentifier: categoryTypeIdentifier)
    case .quantity:
      guard let quantityTypeIdentifier = quantityTypeIdentifier else {
        return nil
      }
      return HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)
    }
  }
  
  /// The data's query type.
  var queryType: HealthKitDataQueryType {
    switch self {
    case .headache,
        .sleepSeconds,
        .sleepOnset,
        .mindfulSession,
        .menstrualDaysSinceCycleStart,
        .menstrualFlowActive:
      return .sample
    case .stepCount,
        .dietaryCaffeine,
        .dietaryWater,
        .timeInDaylight,
        .appleExerciseTime:
      return .statistics(options: .cumulativeSum)
    case .environmentalAudioExposure,
        .headphoneAudioExposure:
      return .statistics(options: .discreteAverage)
    case .respiratoryRate,
        .oxygenSaturation,
        .heartRate,
        .heartRateVariabilitySDNN,
        .bodyTemperature:
      // Averages over the window instead of a single (possibly stale) sample.
      // Body temperature (e.g. a ring writing every 30 minutes) averages well.
      return .statistics(options: .discreteAverage)
    case .restingHeartRate,
        .walkingHeartRateAverage,
        .wristTemperature,
        .basalBodyTemperature:
      // HealthKit writes roughly one of these per day; take the latest.
      return .statistics(options: .mostRecent)
    case .hrvRMSSD, .hrvPNN50, .hrvLFHF:
      // Derived from a dedicated heartbeat-series read; never queried here
      // (`query(endingAt:)` returns nil first because `type` is nil).
      return .sample
    }
  }

  /// Creates a query for the data's window ending at the given date.
  ///
  /// - Parameters:
  ///   - date: The end of the metric's sampling window.
  ///   - completion: Called after the query has completed.
  /// - Returns: A query.
  /// Returns nil (without invoking `completion`) when no query can be built —
  /// e.g. for derived metrics that have no `type`. Callers must treat a nil
  /// return as "no query ran" and balance their own bookkeeping; `completion`
  /// fires only when an actual query executes.
  func query(endingAt date: Date, completion: @escaping (HKQuery?, [HKSample]?, HKQuantity?, Error?) -> Void) -> HKQuery? {
    guard let type = type else {
      return nil
    }

    // Sleep uses overlap semantics (a block that started before the window
    // but overlaps it still counts, clamped when summed). Everything else
    // keeps strict starts: statistics queries count a matched sample's full
    // value, so overlap semantics would double count sums like step count
    // across successive sampling windows.
    let interval = window(endingAt: date)
    let usesOverlapSemantics: Bool
    switch self {
    case .sleepSeconds, .sleepOnset, .menstrualDaysSinceCycleStart, .menstrualFlowActive:
      usesOverlapSemantics = true
    default:
      usesOverlapSemantics = false
    }
    let options: HKQueryOptions = usesOverlapSemantics ? [] : .strictStartDate
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: options)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let limit = Int(Int32.max)
    
    switch queryType {
    case .sample:
      guard let sampleType = type as? HKSampleType else {
        return nil
      }

      return HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { query, samples, error in
        completion(query, samples, nil, error)
      }
    case .statistics(let options):
      guard let quantityType = type as? HKQuantityType else {
        return nil
      }
      return HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { query, statistics, error in
        if options.contains(.mostRecent) {
          completion(query, nil, statistics?.mostRecentQuantity(), error)
        }
        else if options.contains(.discreteAverage) {
          completion(query, nil, statistics?.averageQuantity(), error)
        }
        else if options.contains(.cumulativeSum) {
          completion(query, nil, statistics?.sumQuantity(), error)
        }
        else {
          completion(query, nil, nil, error)
        }
      }
    }
  }
  
}
