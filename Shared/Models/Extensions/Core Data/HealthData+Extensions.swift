//
//  HealthData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import CoreData
import Foundation

/// The set of health metrics that were actually read when a snapshot was
/// taken. Distinguishes "no reading" from a measured zero. The bit
/// assignments are stable and persisted; never reorder them.
struct HealthMetricPresence: OptionSet {
  let rawValue: Int64

  init(rawValue: Int64) {
    self.rawValue = rawValue
  }

  static let sleepSeconds                = HealthMetricPresence(rawValue: 1 << 0)
  static let sleepOnset                  = HealthMetricPresence(rawValue: 1 << 1)
  static let mindfulSession              = HealthMetricPresence(rawValue: 1 << 2)
  static let stepCount                   = HealthMetricPresence(rawValue: 1 << 3)
  static let environmentalAudioExposure  = HealthMetricPresence(rawValue: 1 << 4)
  static let headphoneAudioExposure      = HealthMetricPresence(rawValue: 1 << 5)
  static let heartRate                   = HealthMetricPresence(rawValue: 1 << 6)
  static let restingHeartRate            = HealthMetricPresence(rawValue: 1 << 7)
  static let walkingHeartRateAverage     = HealthMetricPresence(rawValue: 1 << 8)
  static let heartRateVariabilitySDNN    = HealthMetricPresence(rawValue: 1 << 9)
  static let oxygenSaturation            = HealthMetricPresence(rawValue: 1 << 10)
  static let respiratoryRate             = HealthMetricPresence(rawValue: 1 << 11)
  static let dietaryCaffeine             = HealthMetricPresence(rawValue: 1 << 12)
  static let dietaryWater                = HealthMetricPresence(rawValue: 1 << 13)
  static let timeInDaylight              = HealthMetricPresence(rawValue: 1 << 14)
  static let appleExerciseTime           = HealthMetricPresence(rawValue: 1 << 15)
  static let menstrualDaysSinceCycleStart = HealthMetricPresence(rawValue: 1 << 16)
  static let menstrualFlowActive         = HealthMetricPresence(rawValue: 1 << 17)

  /// The presence flag for the given health kit data, if it has one.
  ///
  /// - Parameter data: The health kit data.
  init?(_ data: HealthKitData) {
    switch data {
    case .sleepSeconds: self = .sleepSeconds
    case .sleepOnset: self = .sleepOnset
    case .mindfulSession: self = .mindfulSession
    case .stepCount: self = .stepCount
    case .environmentalAudioExposure: self = .environmentalAudioExposure
    case .headphoneAudioExposure: self = .headphoneAudioExposure
    case .heartRate: self = .heartRate
    case .restingHeartRate: self = .restingHeartRate
    case .walkingHeartRateAverage: self = .walkingHeartRateAverage
    case .heartRateVariabilitySDNN: self = .heartRateVariabilitySDNN
    case .oxygenSaturation: self = .oxygenSaturation
    case .respiratoryRate: self = .respiratoryRate
    case .dietaryCaffeine: self = .dietaryCaffeine
    case .dietaryWater: self = .dietaryWater
    case .timeInDaylight: self = .timeInDaylight
    case .appleExerciseTime: self = .appleExerciseTime
    case .menstrualDaysSinceCycleStart: self = .menstrualDaysSinceCycleStart
    case .menstrualFlowActive: self = .menstrualFlowActive
    case .headache: return nil
    }
  }
}

extension HealthData {

  /// The set of metrics that were actually read for this snapshot.
  var presence: HealthMetricPresence {
    return HealthMetricPresence(rawValue: presentMetrics)
  }

  /// The health kit data that was actually read.
  ///
  /// Only metrics whose presence bit is set are included. Rows written
  /// before presence tracking (a version but no bits) fall back to returning
  /// every column, since those were written unconditionally.
  var healthKitData: [HealthKitData: Double] {
    let presence = presence

    if presence.isEmpty {
      guard version != nil else {
        return [:]
      }

      // Legacy row awaiting backfill.
      return [
        .heartRate: heartRate,
        .mindfulSession: mindfulSeconds,
        .sleepSeconds: sleepSeconds,
        .sleepOnset: sleepOnset,
        .respiratoryRate: respiratoryRate,
        .oxygenSaturation: oxygenSaturation,
        .heartRateVariabilitySDNN: heartRateVariability,
        .walkingHeartRateAverage: walkingHeartRateAverage,
        .restingHeartRate: restingHeartRate,
        .headphoneAudioExposure: headphoneAudioExposure,
        .environmentalAudioExposure: environmentalAudioExposure,
        .stepCount: stepCount
      ]
    }

    var data = [HealthKitData: Double]()
    if presence.contains(.heartRate) { data[.heartRate] = heartRate }
    if presence.contains(.mindfulSession) { data[.mindfulSession] = mindfulSeconds }
    if presence.contains(.sleepSeconds) { data[.sleepSeconds] = sleepSeconds }
    if presence.contains(.sleepOnset), let sleepOnsetAt = sleepOnsetAt {
      data[.sleepOnset] = sleepOnsetAt.timeIntervalSinceReferenceDate
    }
    if presence.contains(.respiratoryRate) { data[.respiratoryRate] = respiratoryRate }
    if presence.contains(.oxygenSaturation) { data[.oxygenSaturation] = oxygenSaturation }
    if presence.contains(.heartRateVariabilitySDNN) { data[.heartRateVariabilitySDNN] = heartRateVariability }
    if presence.contains(.walkingHeartRateAverage) { data[.walkingHeartRateAverage] = walkingHeartRateAverage }
    if presence.contains(.restingHeartRate) { data[.restingHeartRate] = restingHeartRate }
    if presence.contains(.headphoneAudioExposure) { data[.headphoneAudioExposure] = headphoneAudioExposure }
    if presence.contains(.environmentalAudioExposure) { data[.environmentalAudioExposure] = environmentalAudioExposure }
    if presence.contains(.stepCount) { data[.stepCount] = stepCount }
    if presence.contains(.dietaryCaffeine) { data[.dietaryCaffeine] = dietaryCaffeine }
    if presence.contains(.dietaryWater) { data[.dietaryWater] = dietaryWater }
    if presence.contains(.timeInDaylight) { data[.timeInDaylight] = timeInDaylight }
    if presence.contains(.appleExerciseTime) { data[.appleExerciseTime] = appleExerciseTime }
    if presence.contains(.menstrualDaysSinceCycleStart) { data[.menstrualDaysSinceCycleStart] = menstrualDaysSinceCycleStart }
    if presence.contains(.menstrualFlowActive) { data[.menstrualFlowActive] = menstrualFlowActive }
    return data
  }

  // MARK: Initializers

  convenience init(context: NSManagedObjectContext, timestamp: Date?, data: [HealthKitData: Double]?) {
    self.init(context: context)
    updateWithHealthKitData(data, at: timestamp)
  }

}

// MARK: Public methods

extension HealthData {

  /// Updates the health data with the given health kit data.
  ///
  /// Presence bits record which metrics were actually read; columns for
  /// unread metrics keep their previous values but are ignored by readers.
  ///
  /// - Parameters:
  ///   - healthKitData: The health kit data.
  ///   - timestamp: The data's timestamp.
  func updateWithHealthKitData(_ data: [HealthKitData: Double]?, at timestamp: Date?) {
    guard let data = data else {
      // Nothing was read. Record the absence rather than writing zeros that
      // are indistinguishable from real measurements.
      self.timestamp = nil
      version = nil
      presentMetrics = 0
      return
    }

    var presence = HealthMetricPresence()
    for (key, value) in data {
      switch key {
      case .heartRate: heartRate = value
      case .mindfulSession: mindfulSeconds = value
      case .sleepSeconds: sleepSeconds = value
      case .sleepOnset:
        // The dictionary carries the onset as a reference-date interval.
        let onsetDate = Date(timeIntervalSinceReferenceDate: value)
        sleepOnsetAt = onsetDate
        // Keep the legacy seconds-since-midnight column populated.
        sleepOnset = Calendar.current.timeIntervalSinceMidnight(onsetDate)
      case .respiratoryRate: respiratoryRate = value
      case .oxygenSaturation: oxygenSaturation = value
      case .heartRateVariabilitySDNN: heartRateVariability = value
      case .walkingHeartRateAverage: walkingHeartRateAverage = value
      case .restingHeartRate: restingHeartRate = value
      case .headphoneAudioExposure: headphoneAudioExposure = value
      case .environmentalAudioExposure: environmentalAudioExposure = value
      case .stepCount: stepCount = value
      case .dietaryCaffeine: dietaryCaffeine = value
      case .dietaryWater: dietaryWater = value
      case .timeInDaylight: timeInDaylight = value
      case .appleExerciseTime: appleExerciseTime = value
      case .menstrualDaysSinceCycleStart: menstrualDaysSinceCycleStart = value
      case .menstrualFlowActive: menstrualFlowActive = value
      default: continue
      }

      if let flag = HealthMetricPresence(key) {
        presence.insert(flag)
      }
    }

    // Update the presence, data version, and timestamp
    presentMetrics = presence.rawValue
    self.timestamp = timestamp
    version = Constants.trainingDataVersion
  }

}
