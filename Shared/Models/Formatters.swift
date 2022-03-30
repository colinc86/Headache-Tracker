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
    formatter.dateFormat = "h:mm a"
    return formatter
  }()
  
  /// Formats the given date.
  static func formatTime(_ date: Date) -> String {
    return timeFormatter.string(from: date)
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
    let system = AppSettings.shared.general.measurementSystem
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
  
}
