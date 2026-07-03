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
  
  /// Whether or not this is a sharable type.
  var isShareType: Bool {
    switch self {
    case .headache: return true
    default: return false
    }
  }
  
  /// The data's type.
  var dataType: HealthKitDataType {
    switch self {
    case .headache, .sleepSeconds, .sleepOnset, .mindfulSession:
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
    default: return nil
    }
  }

  /// The sampling window to read for this metric, ending at the given date.
  ///
  /// Fast-moving metrics use short trailing windows; sleep uses the previous
  /// evening onward; daily aggregates look back far enough to contain at
  /// least one sample.
  ///
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
    case .restingHeartRate, .walkingHeartRateAverage:
      return DateInterval(start: date.addingTimeInterval(-48.0 * 3600.0), end: date)
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
        .mindfulSession:
      return .sample
    case .stepCount:
      return .statistics(options: .cumulativeSum)
    case .environmentalAudioExposure,
        .headphoneAudioExposure:
      return .statistics(options: .discreteAverage)
    case .respiratoryRate,
        .oxygenSaturation,
        .heartRate,
        .heartRateVariabilitySDNN:
      // Averages over the window instead of a single (possibly stale) sample.
      return .statistics(options: .discreteAverage)
    case .restingHeartRate,
        .walkingHeartRateAverage:
      // HealthKit writes roughly one of these per day; take the latest.
      return .statistics(options: .mostRecent)
    }
  }

  /// Creates a query for the data's window ending at the given date.
  ///
  /// - Parameters:
  ///   - date: The end of the metric's sampling window.
  ///   - completion: Called after the query has completed.
  /// - Returns: A query.
  func query(endingAt date: Date, completion: @escaping (HKQuery?, [HKSample]?, HKQuantity?, Error?) -> Void) -> HKQuery? {
    guard let type = type else {
      completion(nil, nil, nil, nil)
      return nil
    }

    // Default overlap semantics: a sleep block that started before the
    // window but overlaps it still counts.
    let interval = window(endingAt: date)
    let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let limit = Int(Int32.max)
    
    switch queryType {
    case .sample:
      guard let sampleType = type as? HKSampleType else {
        completion(nil, nil, nil, nil)
        return nil
      }
      
      return HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { query, samples, error in
        completion(query, samples, nil, error)
      }
    case .statistics(let options):
      guard let quantityType = type as? HKQuantityType else {
        completion(nil, nil, nil, nil)
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
