//
//  FeatureMedians.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// Per-feature medians computed from training data and persisted beside the
/// models, so missing values are imputed identically at training and
/// inference time. Imputing with the median keeps tree splits meaningful,
/// unlike the previous 0.0 fill that conflated "no reading" with a measured
/// zero.
struct FeatureMedians: Codable {

  /// Medians per health metric. Sleep onset is stored in seconds since
  /// midnight, matching the feature the model consumes.
  var healthKit = [HealthKitData: Double]()

  /// The median station pressure in kilopascals.
  var pressure: Double?

  /// The median device pressure in kilopascals.
  var devicePressure: Double?

  /// The median humidity as a decimal percent.
  var humidity: Double?

  /// The median temperature in celsius.
  var temperature: Double?

  /// The median pressure change in kilopascals.
  var sigmaPressure: Double?

  /// The median humidity change as a decimal percent.
  var sigmaHumidity: Double?

  /// The median temperature change in celsius.
  var sigmaTemperature: Double?

  // MARK: Static methods

  /// The median of an array of values.
  ///
  /// - Parameter values: The values.
  /// - Returns: The median, or nil for an empty array.
  static func median(of values: [Double]) -> Double? {
    guard !values.isEmpty else {
      return nil
    }

    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count % 2 == 0 {
      return (sorted[middle - 1] + sorted[middle]) / 2.0
    }
    return sorted[middle]
  }

  /// Computes per-feature medians from the present values of the given
  /// inputs.
  ///
  /// - Parameter inputs: The model inputs (typically the training slice).
  /// - Returns: The medians.
  static func computed(from inputs: [ModelInput]) -> FeatureMedians {
    var medians = FeatureMedians()

    for data in HealthKitData.allCases where !data.isShareType {
      let values: [Double] = inputs.compactMap { input in
        guard let value = input.healthKitData?[data] else {
          return nil
        }

        // Sleep onset is carried as a reference-date interval; its feature
        // space is seconds since midnight.
        if data == .sleepOnset && value > 86400.0 {
          return Calendar.current.timeIntervalSinceMidnight(Date(timeIntervalSinceReferenceDate: value))
        }
        return value
      }

      if let median = median(of: values) {
        medians.healthKit[data] = median
      }
    }

    let weather = inputs.compactMap({ $0.weatherStatistics })
    medians.pressure = median(of: weather.map({ $0.currentPressure }))
    medians.devicePressure = median(of: weather.compactMap({ $0.barometricPressure }))
    medians.humidity = median(of: weather.map({ $0.currentHumidity }))
    medians.temperature = median(of: weather.map({ $0.currentTemperature }))
    medians.sigmaPressure = median(of: weather.map({ $0.sigmaPressure }))
    medians.sigmaHumidity = median(of: weather.map({ $0.sigmaHumidity }))
    medians.sigmaTemperature = median(of: weather.map({ $0.sigmaTemperature }))

    return medians
  }

  // MARK: Public methods

  /// Fills the input's missing values with medians, leaving present values
  /// untouched.
  ///
  /// - Parameter input: The input to impute.
  /// - Returns: The imputed input.
  func imputing(_ input: ModelInput) -> ModelInput {
    var imputed = input

    var healthKitData = input.healthKitData ?? [:]
    for (key, median) in healthKit where healthKitData[key] == nil {
      healthKitData[key] = median
    }
    imputed.healthKitData = healthKitData

    if input.weatherStatistics == nil {
      // No weather at all: substitute the median snapshot when available.
      if let pressure = pressure, let humidity = humidity, let temperature = temperature {
        imputed.weatherStatistics = WeatherStatistics(
          barometricPressure: devicePressure,
          currentPressure: pressure,
          currentHumidity: humidity,
          currentTemperature: temperature,
          sigmaPressure: sigmaPressure ?? 0.0,
          sigmaHumidity: sigmaHumidity ?? 0.0,
          sigmaTemperature: sigmaTemperature ?? 0.0)
      }
    }
    else if input.weatherStatistics?.barometricPressure == nil, let devicePressure = devicePressure, let weather = input.weatherStatistics {
      imputed.weatherStatistics = WeatherStatistics(
        barometricPressure: devicePressure,
        currentPressure: weather.currentPressure,
        currentHumidity: weather.currentHumidity,
        currentTemperature: weather.currentTemperature,
        sigmaPressure: weather.sigmaPressure,
        sigmaHumidity: weather.sigmaHumidity,
        sigmaTemperature: weather.sigmaTemperature)
    }

    return imputed
  }

}
