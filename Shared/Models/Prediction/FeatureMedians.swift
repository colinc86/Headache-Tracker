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

  /// Per-statistic medians of each health metric's window context. Missing
  /// from sidecars written before temporal context existed.
  var healthWindow = [HealthKitData: WindowStatistics]()

  /// Per-statistic medians of each weather field's window context.
  var weatherWindow = [WeatherField: WindowStatistics]()

  init() {
  }

  private enum CodingKeys: String, CodingKey {
    case healthKit, pressure, devicePressure, humidity, temperature, sigmaPressure, sigmaHumidity, sigmaTemperature
    case healthWindow, weatherWindow
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    healthKit = try container.decodeIfPresent([HealthKitData: Double].self, forKey: .healthKit) ?? [:]
    pressure = try container.decodeIfPresent(Double.self, forKey: .pressure)
    devicePressure = try container.decodeIfPresent(Double.self, forKey: .devicePressure)
    humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
    temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
    sigmaPressure = try container.decodeIfPresent(Double.self, forKey: .sigmaPressure)
    sigmaHumidity = try container.decodeIfPresent(Double.self, forKey: .sigmaHumidity)
    sigmaTemperature = try container.decodeIfPresent(Double.self, forKey: .sigmaTemperature)
    healthWindow = try container.decodeIfPresent([HealthKitData: WindowStatistics].self, forKey: .healthWindow) ?? [:]
    weatherWindow = try container.decodeIfPresent([WeatherField: WindowStatistics].self, forKey: .weatherWindow) ?? [:]
  }

  // MARK: Static methods

  /// The per-statistic medians of a set of window statistics.
  ///
  /// - Parameter values: The present statistics.
  /// - Returns: The medians, or nil when nothing is present.
  static func windowMedians(of values: [WindowStatistics]) -> WindowStatistics? {
    guard !values.isEmpty else {
      return nil
    }
    let medians = WindowStatistics(
      mean24h: median(of: values.compactMap({ $0.mean24h })),
      delta24h: median(of: values.compactMap({ $0.delta24h })),
      range48h: median(of: values.compactMap({ $0.range48h })),
      range72h: median(of: values.compactMap({ $0.range72h })),
      delta6h: median(of: values.compactMap({ $0.delta6h })))
    return medians.isEmpty ? nil : medians
  }

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

    for metric in HealthKitData.windowMetrics {
      if let window = windowMedians(of: inputs.compactMap({ $0.healthWindowStatistics?[metric] })) {
        medians.healthWindow[metric] = window
      }
    }
    for field in WeatherField.windowFields {
      if let window = windowMedians(of: inputs.compactMap({ $0.weatherWindowStatistics?[field] })) {
        medians.weatherWindow[field] = window
      }
    }

    return medians
  }

  /// Fills the missing statistics of a window entry with medians.
  private static func filled(_ statistics: WindowStatistics?, with medians: WindowStatistics) -> WindowStatistics {
    var result = statistics ?? WindowStatistics()
    result.mean24h = result.mean24h ?? medians.mean24h
    result.delta24h = result.delta24h ?? medians.delta24h
    result.range48h = result.range48h ?? medians.range48h
    result.range72h = result.range72h ?? medians.range72h
    result.delta6h = result.delta6h ?? medians.delta6h
    return result
  }

  // MARK: Public methods

  /// How much of the model's expected raw input was measured, before
  /// `imputing(_:)` fills the rest. Expected signals are the enabled health
  /// metrics that have a training median (a metric the user switched off
  /// never reads as missing) plus weather when the medians carry a snapshot.
  ///
  /// - Parameters:
  ///   - input: The un-imputed input.
  ///   - enabled: Whether a metric is enabled for prediction.
  /// - Returns: The coverage.
  func coverage(of input: ModelInput, enabled: (HealthKitData) -> Bool) -> InputCoverage {
    let expectedMetrics = healthKit.keys.filter(enabled)
    var present = expectedMetrics.filter({ input.healthKitData?[$0] != nil }).count
    var expected = expectedMetrics.count

    if pressure != nil, humidity != nil, temperature != nil {
      expected += 1
      if input.weatherStatistics != nil {
        present += 1
      }
    }

    return InputCoverage(presentSignals: present, expectedSignals: expected)
  }

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

    // Window context: fill each missing statistic per metric. A zero would
    // read as "flat" rather than "unknown", so the medians apply here too.
    if !healthWindow.isEmpty {
      var health = input.healthWindowStatistics ?? [:]
      for (metric, medians) in healthWindow {
        health[metric] = FeatureMedians.filled(health[metric], with: medians)
      }
      imputed.healthWindowStatistics = health
    }
    if !weatherWindow.isEmpty {
      var weather = input.weatherWindowStatistics ?? [:]
      for (field, medians) in weatherWindow {
        weather[field] = FeatureMedians.filled(weather[field], with: medians)
      }
      imputed.weatherWindowStatistics = weather
    }

    return imputed
  }

}
