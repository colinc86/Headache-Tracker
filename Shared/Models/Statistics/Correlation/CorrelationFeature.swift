//
//  CorrelationFeature.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

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
    case .heartRateVariability: return "waveform.path.ecg"
    case .oxygenSaturation: return "lungs.fill"
    case .respiratoryRate: return "wind"
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
    case .pressure, .devicePressure, .sigmaPressure:
      return Formatters.formatMeasurementDelta(Measurement(value: value, unit: UnitPressure.kilopascals))
    case .humidity, .sigmaHumidity:
      return String(format: "%.0f%%", value * 100.0)
    case .temperature, .sigmaTemperature:
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
    case .pressure: return "Current Pressure"
    case .devicePressure: return "Device Pressure"
    case .humidity: return "Current Humidity"
    case .temperature: return "Current Temperature"
    case .sigmaPressure: return "Sigma Pressure"
    case .sigmaHumidity: return "Sigma Humidity"
    case .sigmaTemperature: return "Sigma Temperature"
    }
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
        case .heartRateVariabilitySDNN: values[.heartRateVariability] = value
        case .oxygenSaturation: values[.oxygenSaturation] = value
        case .respiratoryRate: values[.respiratoryRate] = value
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
