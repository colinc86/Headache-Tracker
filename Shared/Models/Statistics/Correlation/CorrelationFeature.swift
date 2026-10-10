//
//  CorrelationFeature.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// A grouping of signals for presentation — the axes a person's headaches can
/// lean toward ("a sleep person" vs "a weather person").
enum SignalDomain: String, CaseIterable, Identifiable {
  case sleep
  case autonomic
  case activity
  case sound
  case lifestyle
  case cycle
  case weather

  var id: String { rawValue }

  /// A title suitable for the user interface.
  var title: String {
    switch self {
    case .sleep: return "Sleep"
    case .autonomic: return "Heart & Autonomic"
    case .activity: return "Activity"
    case .sound: return "Sound"
    case .lifestyle: return "Lifestyle"
    case .cycle: return "Cycle"
    case .weather: return "Weather"
    }
  }

  /// The system image representing the domain.
  var systemImage: String {
    switch self {
    case .sleep: return "bed.double.fill"
    case .autonomic: return "waveform.path.ecg"
    case .activity: return "figure.walk"
    case .sound: return "ear"
    case .lifestyle: return "cup.and.saucer.fill"
    case .cycle: return "calendar.circle.fill"
    case .weather: return "cloud.sun.fill"
    }
  }

  /// A stable display order.
  var sortOrder: Int {
    return SignalDomain.allCases.firstIndex(of: self) ?? 0
  }
}

/// A health or weather signal that can be correlated against headaches.
enum CorrelationFeature: String, CaseIterable, Codable, Identifiable {

  // Health
  case sleepSeconds
  case sleepOnsetHour
  case mindfulSeconds
  case stepCount
  case environmentalAudioExposure
  case headphoneAudioExposure
  case heartRate
  case restingHeartRate
  case walkingHeartRateAverage
  case heartRateVariability
  case oxygenSaturation
  case respiratoryRate
  case bodyTemperature
  case wristTemperature
  case basalBodyTemperature
  case hrvRMSSD
  case hrvPNN50
  case hrvLFHF

  // Nutrition, activity, and cycle
  case dietaryCaffeine
  case dietaryWater
  case timeInDaylight
  case exerciseMinutes
  case menstrualDaysSinceCycleStart
  case menstrualFlowActive

  // Weather
  case pressure
  case devicePressure
  case humidity
  case temperature
  case sigmaPressure
  case sigmaHumidity
  case sigmaTemperature

  var id: String {
    return rawValue
  }

  /// A title suitable for the user interface.
  var title: String {
    switch self {
    case .sleepSeconds: return "Sleep Duration"
    case .sleepOnsetHour: return "Sleep Onset Time"
    case .mindfulSeconds: return "Mindful Minutes"
    case .stepCount: return "Step Count"
    case .environmentalAudioExposure: return "Environmental Noise"
    case .headphoneAudioExposure: return "Headphone Audio"
    case .heartRate: return "Heart Rate"
    case .restingHeartRate: return "Resting Heart Rate"
    case .walkingHeartRateAverage: return "Walking Heart Rate"
    case .heartRateVariability: return "Heart Rate Variability"
    case .oxygenSaturation: return "Oxygen Saturation"
    case .respiratoryRate: return "Respiratory Rate"
    case .bodyTemperature: return "Body Temperature"
    case .wristTemperature: return "Wrist Temperature"
    case .basalBodyTemperature: return "Basal Body Temperature"
    case .hrvRMSSD: return "HRV (RMSSD)"
    case .hrvPNN50: return "HRV (pNN50)"
    case .hrvLFHF: return "HRV (LF/HF)"
    case .dietaryCaffeine: return "Caffeine Intake"
    case .dietaryWater: return "Water Intake"
    case .timeInDaylight: return "Time in Daylight"
    case .exerciseMinutes: return "Exercise Minutes"
    case .menstrualDaysSinceCycleStart: return "Cycle Day"
    case .menstrualFlowActive: return "Menstrual Flow"
    case .pressure: return "Barometric Pressure"
    case .devicePressure: return "Device Pressure"
    case .humidity: return "Humidity"
    case .temperature: return "Temperature"
    case .sigmaPressure: return "Pressure Change"
    case .sigmaHumidity: return "Humidity Change"
    case .sigmaTemperature: return "Temperature Change"
    }
  }

  /// The system image to represent the feature.
  var systemImage: String {
    switch self {
    case .sleepSeconds, .sleepOnsetHour: return "bed.double.fill"
    case .mindfulSeconds: return "brain.head.profile"
    case .stepCount: return "figure.walk"
    case .environmentalAudioExposure, .headphoneAudioExposure: return "ear"
    case .heartRate, .restingHeartRate, .walkingHeartRateAverage: return "heart.fill"
    case .heartRateVariability, .hrvRMSSD, .hrvPNN50, .hrvLFHF: return "waveform.path.ecg"
    case .oxygenSaturation: return "lungs.fill"
    case .respiratoryRate: return "wind"
    case .bodyTemperature, .wristTemperature, .basalBodyTemperature: return "thermometer.medium"
    case .dietaryCaffeine: return "cup.and.saucer.fill"
    case .dietaryWater: return "drop.fill"
    case .timeInDaylight: return "sun.max.fill"
    case .exerciseMinutes: return "figure.run"
    case .menstrualDaysSinceCycleStart, .menstrualFlowActive: return "calendar.circle.fill"
    case .pressure, .devicePressure, .sigmaPressure: return "barometer"
    case .humidity, .sigmaHumidity: return "humidity"
    case .temperature, .sigmaTemperature: return "thermometer"
    }
  }

  /// Formats a value of this feature for the user interface.
  ///
  /// - Parameter value: The raw feature value.
  /// - Returns: A display string.
  func format(_ value: Double) -> String {
    switch self {
    case .sleepSeconds, .mindfulSeconds:
      return Formatters.formatInterval(value)
    case .sleepOnsetHour:
      // Hours after 6 PM, mapped back to a clock time.
      let clockSeconds = (value * 3600.0 + 18.0 * 3600.0).truncatingRemainder(dividingBy: 86400.0)
      return Formatters.formatTime(Calendar.current.startOfDay(for: Date()).addingTimeInterval(clockSeconds))
    case .stepCount:
      return String(format: "%.0f steps", value)
    case .environmentalAudioExposure, .headphoneAudioExposure:
      return String(format: "%.0f dB", value)
    case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
      return String(format: "%.0f bpm", value)
    case .heartRateVariability:
      return String(format: "%.0f ms", value)
    case .oxygenSaturation:
      return String(format: "%.0f%%", value * 100.0)
    case .respiratoryRate:
      return String(format: "%.1f br/min", value)
    case .bodyTemperature, .wristTemperature, .basalBodyTemperature:
      return Formatters.formatMeasurement(Measurement(value: value, unit: UnitTemperature.celsius))
    case .hrvRMSSD:
      return String(format: "%.0f ms", value)
    case .hrvPNN50:
      return String(format: "%.0f%%", value * 100.0)
    case .hrvLFHF:
      return String(format: "%.2f", value)
    case .dietaryCaffeine:
      return String(format: "%.0f mg", value)
    case .dietaryWater:
      return String(format: "%.0f mL", value)
    case .timeInDaylight, .exerciseMinutes:
      return String(format: "%.0f min", value)
    case .menstrualDaysSinceCycleStart:
      // Bare number: every display site pairs this with the "Cycle Day" title
      // (brief reason, inspector row, the trigger screen's own title), so a
      // "day " prefix here only produced redundant "Cycle Day day 14" clutter.
      return String(format: "%.0f", value)
    case .menstrualFlowActive:
      return value > 0.5 ? "yes" : "no"
    case .pressure, .devicePressure, .sigmaPressure:
      return Formatters.formatMeasurementDelta(Measurement(value: value, unit: UnitPressure.kilopascals))
    case .humidity, .sigmaHumidity:
      return String(format: "%.0f%%", value * 100.0)
    case .temperature:
      // Absolute temperature: convert with the +32°F offset. (The delta
      // formatter drops it, which showed every reading exactly 32°F too low.)
      return Formatters.formatMeasurement(Measurement(value: value, unit: UnitTemperature.celsius))
    case .sigmaTemperature:
      // A standard deviation is a spread, so the offset-free delta conversion
      // is correct here.
      return Formatters.formatMeasurementDelta(Measurement(value: value, unit: UnitTemperature.celsius))
    }
  }

  /// The ML feature name corresponding to this signal, for looking up the
  /// trained models' permutation feature importances.
  var mlFeatureName: String {
    switch self {
    case .sleepSeconds: return "Sleep Seconds"
    case .sleepOnsetHour: return "Sleep Onset"
    case .mindfulSeconds: return "Mindful Session"
    case .stepCount: return "Step Count"
    case .environmentalAudioExposure: return "Environment Audio Exposure"
    case .headphoneAudioExposure: return "Headphone Audio Exposure"
    case .heartRate: return "Heart Rate"
    case .restingHeartRate: return "Resting Heart Rate"
    case .walkingHeartRateAverage: return "Walking Heart Rate Average"
    case .heartRateVariability: return "Heart Rate Variability"
    case .oxygenSaturation: return "Oxygen Saturation"
    case .respiratoryRate: return "Respiratory Rate"
    case .bodyTemperature: return "Body Temperature"
    case .wristTemperature: return "Wrist Temperature"
    case .basalBodyTemperature: return "Basal Body Temperature"
    case .hrvRMSSD: return "HRV RMSSD"
    case .hrvPNN50: return "HRV pNN50"
    case .hrvLFHF: return "HRV LF HF"
    case .dietaryCaffeine: return "Dietary Caffeine"
    case .dietaryWater: return "Dietary Water"
    case .timeInDaylight: return "Time In Daylight"
    case .exerciseMinutes: return "Exercise Minutes"
    case .menstrualDaysSinceCycleStart: return "Cycle Day"
    case .menstrualFlowActive: return "Menstrual Flow"
    case .pressure: return "Current Pressure"
    case .devicePressure: return "Device Pressure"
    case .humidity: return "Current Humidity"
    case .temperature: return "Current Temperature"
    case .sigmaPressure: return "Sigma Pressure"
    case .sigmaHumidity: return "Sigma Humidity"
    case .sigmaTemperature: return "Sigma Temperature"
    }
  }

  /// The domain this signal belongs to, for grouping in the UI.
  var domain: SignalDomain {
    switch self {
    case .sleepSeconds, .sleepOnsetHour:
      return .sleep
    case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateVariability,
        .oxygenSaturation, .respiratoryRate, .bodyTemperature, .wristTemperature,
        .basalBodyTemperature, .hrvRMSSD, .hrvPNN50, .hrvLFHF:
      return .autonomic
    case .stepCount, .exerciseMinutes, .timeInDaylight, .mindfulSeconds:
      return .activity
    case .environmentalAudioExposure, .headphoneAudioExposure:
      return .sound
    case .dietaryCaffeine, .dietaryWater:
      return .lifestyle
    case .menstrualDaysSinceCycleStart, .menstrualFlowActive:
      return .cycle
    case .pressure, .devicePressure, .humidity, .temperature, .sigmaPressure, .sigmaHumidity, .sigmaTemperature:
      return .weather
    }
  }

  /// The correlation feature a HealthKit metric maps to, mirroring the value
  /// mapping in `TrainingData.correlationSample`. Nil for the write-only
  /// headache type and the correlation-only metrics that feed no model column
  /// but still map (they simply have no attribution).
  init?(healthKitData: HealthKitData) {
    switch healthKitData {
    case .sleepSeconds: self = .sleepSeconds
    case .sleepOnset: self = .sleepOnsetHour
    case .mindfulSession: self = .mindfulSeconds
    case .stepCount: self = .stepCount
    case .environmentalAudioExposure: self = .environmentalAudioExposure
    case .headphoneAudioExposure: self = .headphoneAudioExposure
    case .heartRate: self = .heartRate
    case .restingHeartRate: self = .restingHeartRate
    case .walkingHeartRateAverage: self = .walkingHeartRateAverage
    case .heartRateVariabilitySDNN: self = .heartRateVariability
    case .oxygenSaturation: self = .oxygenSaturation
    case .respiratoryRate: self = .respiratoryRate
    case .dietaryCaffeine: self = .dietaryCaffeine
    case .dietaryWater: self = .dietaryWater
    case .timeInDaylight: self = .timeInDaylight
    case .appleExerciseTime: self = .exerciseMinutes
    case .menstrualDaysSinceCycleStart: self = .menstrualDaysSinceCycleStart
    case .menstrualFlowActive: self = .menstrualFlowActive
    case .bodyTemperature: self = .bodyTemperature
    case .wristTemperature: self = .wristTemperature
    case .basalBodyTemperature: self = .basalBodyTemperature
    case .hrvRMSSD: self = .hrvRMSSD
    case .hrvPNN50: self = .hrvPNN50
    case .hrvLFHF: self = .hrvLFHF
    case .headache: return nil
    }
  }

  /// The feature a trained model's importance column refers to, tolerating
  /// the baseline-relative column variants (`"… Baseline Z"` /
  /// `"… Baseline Slope"`) that derive from a base metric — so a top factor
  /// renders as a friendly title instead of the raw column string.
  ///
  /// - Parameter name: The ML feature/column name from the model importances.
  /// - Returns: The matching feature, or nil.
  static func matching(mlFeatureName name: String) -> CorrelationFeature? {
    if let exact = allCases.first(where: { $0.mlFeatureName == name }) {
      return exact
    }

    // Strip the baseline-relative suffix to the base column. Two providers
    // abbreviate their base ("HRV", "Sleep"), so alias those to the raw name.
    var base = name
    for suffix in [" Baseline Slope", " Baseline Z"] + TemporalContextInput.suffixes where base.hasSuffix(suffix) {
      base = String(base.dropLast(suffix.count))
    }
    let aliases = ["HRV": "Heart Rate Variability", "Sleep": "Sleep Seconds"]
    let resolved = aliases[base] ?? base
    return allCases.first(where: { $0.mlFeatureName == resolved })
  }

  /// A sleep onset date as continuous hours after 6 PM, avoiding the
  /// discontinuity at midnight for typical bedtimes.
  ///
  /// - Parameter date: The onset date.
  /// - Returns: Hours after 6 PM.
  static func hoursAfterSixPM(_ date: Date) -> Double {
    let secondsSinceMidnight = Calendar.current.timeIntervalSinceMidnight(date)
    return (secondsSinceMidnight + 6.0 * 3600.0).truncatingRemainder(dividingBy: 86400.0) / 3600.0
  }

}

extension TrainingData {

  /// The row's correlation sample: presence-gated feature values keyed by
  /// correlation feature. Nil when the row has no timestamp or no values.
  var correlationSample: CorrelationSample? {
    guard let timestamp = timestamp else {
      return nil
    }

    var values = [CorrelationFeature: Double]()

    if let healthData = healthData {
      let presence = healthData.presence
      for (key, value) in healthData.healthKitData {
        switch key {
        case .sleepSeconds: values[.sleepSeconds] = value
        case .sleepOnset:
          // Only presence-tracked rows carry a reconstructible onset date;
          // legacy rows used a sentinel-laden seconds-since-midnight value.
          if presence.contains(.sleepOnset) {
            values[.sleepOnsetHour] = CorrelationFeature.hoursAfterSixPM(Date(timeIntervalSinceReferenceDate: value))
          }
        case .mindfulSession: values[.mindfulSeconds] = value
        case .stepCount: values[.stepCount] = value
        case .environmentalAudioExposure: values[.environmentalAudioExposure] = value
        case .headphoneAudioExposure: values[.headphoneAudioExposure] = value
        case .heartRate: values[.heartRate] = value
        case .restingHeartRate: values[.restingHeartRate] = value
        case .walkingHeartRateAverage: values[.walkingHeartRateAverage] = value
        case .heartRateVariabilitySDNN:
          // HRV changed units (seconds -> milliseconds) with presence
          // tracking; legacy rows would mix scales 1000x apart into the
          // same series, so only presence-tracked values participate.
          if presence.contains(.heartRateVariabilitySDNN) {
            values[.heartRateVariability] = value
          }
        case .oxygenSaturation: values[.oxygenSaturation] = value
        case .respiratoryRate: values[.respiratoryRate] = value
        case .dietaryCaffeine: values[.dietaryCaffeine] = value
        case .dietaryWater: values[.dietaryWater] = value
        case .timeInDaylight: values[.timeInDaylight] = value
        case .appleExerciseTime: values[.exerciseMinutes] = value
        case .menstrualDaysSinceCycleStart: values[.menstrualDaysSinceCycleStart] = value
        case .menstrualFlowActive: values[.menstrualFlowActive] = value
        case .bodyTemperature: values[.bodyTemperature] = value
        case .wristTemperature: values[.wristTemperature] = value
        case .basalBodyTemperature: values[.basalBodyTemperature] = value
        case .hrvRMSSD: values[.hrvRMSSD] = value
        case .hrvPNN50: values[.hrvPNN50] = value
        case .hrvLFHF: values[.hrvLFHF] = value
        case .headache: break
        }
      }
    }

    if let weatherData = weatherData, weatherData.version != nil {
      let presence = weatherData.presence
      if presence.isEmpty {
        // Legacy row: station fields were written unconditionally; device
        // pressure used 0.0 as its "not captured" sentinel.
        values[.pressure] = weatherData.pressure
        values[.humidity] = weatherData.humidity
        values[.temperature] = weatherData.temperature
        values[.sigmaPressure] = weatherData.sigmaPressure
        values[.sigmaHumidity] = weatherData.sigmaHumidity
        values[.sigmaTemperature] = weatherData.sigmaTemperature
        if weatherData.devicePressure != 0.0 {
          values[.devicePressure] = weatherData.devicePressure
        }
      }
      else {
        if presence.contains(.pressure) { values[.pressure] = weatherData.pressure }
        if presence.contains(.humidity) { values[.humidity] = weatherData.humidity }
        if presence.contains(.temperature) { values[.temperature] = weatherData.temperature }
        if presence.contains(.sigmaPressure) { values[.sigmaPressure] = weatherData.sigmaPressure }
        if presence.contains(.sigmaHumidity) { values[.sigmaHumidity] = weatherData.sigmaHumidity }
        if presence.contains(.sigmaTemperature) { values[.sigmaTemperature] = weatherData.sigmaTemperature }
        if presence.contains(.devicePressure) { values[.devicePressure] = weatherData.devicePressure }
      }
    }

    guard !values.isEmpty else {
      return nil
    }

    return CorrelationSample(timestamp: timestamp, values: values)
  }

}
