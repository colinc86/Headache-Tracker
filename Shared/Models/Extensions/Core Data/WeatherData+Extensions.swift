//
//  WeatherData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import CoreData
import Foundation

/// The set of weather fields that were actually captured when a snapshot was
/// taken. Distinguishes "no reading" from a measured zero. The bit
/// assignments are stable and persisted; never reorder them.
struct WeatherFieldPresence: OptionSet {
  let rawValue: Int64

  static let devicePressure   = WeatherFieldPresence(rawValue: 1 << 0)
  static let pressure         = WeatherFieldPresence(rawValue: 1 << 1)
  static let humidity         = WeatherFieldPresence(rawValue: 1 << 2)
  static let temperature      = WeatherFieldPresence(rawValue: 1 << 3)
  static let sigmaPressure    = WeatherFieldPresence(rawValue: 1 << 4)
  static let sigmaHumidity    = WeatherFieldPresence(rawValue: 1 << 5)
  static let sigmaTemperature = WeatherFieldPresence(rawValue: 1 << 6)

  /// All fields sourced from the weather service.
  static let station: WeatherFieldPresence = [.pressure, .humidity, .temperature, .sigmaPressure, .sigmaHumidity, .sigmaTemperature]
}

extension WeatherData {

  /// The set of fields that were actually captured for this snapshot.
  var presence: WeatherFieldPresence {
    return WeatherFieldPresence(rawValue: presentFields)
  }

  /// The device pressure measurement in kilopascals.
  var devicePressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: devicePressure, unit: .kilopascals)
  }
  
  /// The weather pressure measurement in kilopascals.
  var pressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: pressure, unit: .kilopascals)
  }
  
  /// The weather humidity measurement as a decimal.
  var humidityMeasurement: Measurement<UnitRate> {
    Measurement(value: humidity, unit: .decimal)
  }
  
  /// The weather temperature measurement in celsius.
  var temperatureMeasurement: Measurement<UnitTemperature> {
    Measurement(value: temperature, unit: .celsius)
  }
  
  /// The weather data's weather statistics.
  var weatherStatistics: WeatherStatistics {
    // Rows written before presence tracking used devicePressure == 0.0 as
    // the "not captured" sentinel.
    let hasDevicePressure = presence.isEmpty ? devicePressure != 0.0 : presence.contains(.devicePressure)

    return WeatherStatistics(
      barometricPressure: hasDevicePressure ? devicePressure : nil,
      currentPressure: pressure,
      currentHumidity: humidity,
      currentTemperature: temperature,
      sigmaPressure: sigmaPressure,
      sigmaHumidity: sigmaHumidity,
      sigmaTemperature: sigmaTemperature)
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, timestamp: Date?, weatherStatistics: WeatherStatistics?) {
    self.init(context: context)
    updateWithWeatherStatistics(weatherStatistics, at: timestamp)
  }
  
}

// MARK: Public methods

extension WeatherData {
  
  /// Updates the weather data with the given weather statistics.
  ///
  /// - Parameters:
  ///   - weatherStatistics: The weather statistics.
  ///   - timestamp: The weather statistic's timestamp.
  func updateWithWeatherStatistics(_ weatherStatistics: WeatherStatistics?, at timestamp: Date?) {
    guard let weatherStatistics = weatherStatistics else {
      // Nothing was captured. Record the absence rather than writing zeros
      // that are indistinguishable from real measurements.
      self.timestamp = nil
      version = nil
      presentFields = 0
      return
    }

    // The device-barometer reading was captured from the phone's own sensor at
    // log time. It's location-independent and can't be re-derived from a
    // historical weather query, so a re-fetch (which only carries station
    // weather for a past date) must preserve it rather than dropping it.
    let priorPresence = presence
    let hadDevicePressure = priorPresence.isEmpty ? devicePressure != 0.0 : priorPresence.contains(.devicePressure)

    var presence = WeatherFieldPresence.station
    if let barometricPressure = weatherStatistics.barometricPressure {
      devicePressure = barometricPressure
      presence.insert(.devicePressure)
    }
    else if hadDevicePressure {
      // Keep the previously recorded device pressure and its presence bit.
      presence.insert(.devicePressure)
    }

    pressure = weatherStatistics.currentPressure
    humidity = weatherStatistics.currentHumidity
    temperature = weatherStatistics.currentTemperature
    sigmaPressure = weatherStatistics.sigmaPressure
    sigmaHumidity = weatherStatistics.sigmaHumidity
    sigmaTemperature = weatherStatistics.sigmaTemperature

    // Update the presence, data version, and timestamp
    presentFields = presence.rawValue
    self.timestamp = timestamp
    version = Constants.trainingDataWeatherVersion
  }
  
}
