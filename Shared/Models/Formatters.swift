//
//  Formatters.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import Foundation

struct Formatters {
  
  /// The date components formatter for displaying time intervals.
  static let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.minute, .hour, .day]
    formatter.maximumUnitCount = 2
    return formatter
  }()
  
  /// Formats the given time interval.
  static func formatInterval(_ interval: TimeInterval) -> String {
    return dateComponentsFormatter.string(from: interval) ?? "0 min"
  }
  
  /// The date formatter to use when displaying times from dates.
  static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    // `.short` respects the user's 12-/24-hour Settings preference; a hardcoded
    // "h:mm a" format would force AM/PM even for someone on a 24-hour clock.
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
  }()
  
  /// Formats the given date.
  static func formatTime(_ date: Date) -> String {
    return timeFormatter.string(from: date)
  }

  /// The time alone when `date` is today, otherwise the abbreviated date plus
  /// the time — so a bare "10:30 AM" is never ambiguous about which day it
  /// refers to (e.g. medications logged across a multi-day headache).
  static func formatTimeWithDay(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
      return formatTime(date)
    }
    return date.formattedDate() + " at " + formatTime(date)
  }
  
  /// The measurement formatter to use when displaying unit values.
  static let measurementFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = [.naturalScale, .providedUnit]
    
    let numberFormatter = NumberFormatter()
    numberFormatter.maximumFractionDigits = 2
    formatter.numberFormatter = numberFormatter
    return formatter
  }()
  
  /// Formats the given measurement.
  static func formatMeasurement<T: Dimension>(_ measurement: Measurement<T>) -> String {
    let preferences = Preferences.General()
    let system = preferences.measurementSystem
    let convertedUnit: Measurement<T>
    if measurement.unit is UnitPressure {
      convertedUnit = measurement.converted(to: system.pressureUnit as! T)
    }
    else if measurement.unit is UnitTemperature {
      convertedUnit = measurement.converted(to: system.temperatureUnit as! T)
    }
    else if measurement.unit is UnitRate {
      convertedUnit = measurement.converted(to: system.humidityUnit as! T)
    }
    else {
      convertedUnit = measurement
    }
    
    return measurementFormatter.string(from: convertedUnit)
  }

  /// Formats the given measurement as a difference between two values.
  ///
  /// Temperature deltas are converted by scale only, since applying the
  /// affine celsius-to-fahrenheit conversion to a difference would add the
  /// 32° offset.
  static func formatMeasurementDelta<T: Dimension>(_ measurement: Measurement<T>) -> String {
    if measurement.unit is UnitTemperature {
      let unit = Preferences.General().measurementSystem.temperatureUnit
      let value = unit == .fahrenheit ? measurement.value * 9.0 / 5.0 : measurement.value
      return measurementFormatter.string(from: Measurement(value: value, unit: unit))
    }
    return formatMeasurement(measurement)
  }

}
