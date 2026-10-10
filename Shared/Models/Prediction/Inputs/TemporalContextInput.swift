//
//  TemporalContextInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import CoreML
import Foundation

/// Trailing fixed-clock-window context for the metrics the model otherwise
/// sees only as a snapshot: how far the current value sits from its 24-hour
/// mean and how much it swung over the last two days.
///
/// The base columns (24h delta and 48h range) are emitted for every window
/// metric; the offline study credited the 48h range with most of the gain.
/// The extended columns (24h mean, 72h range, 6h delta) are emitted only for
/// the features the personalization step promoted — those the correlation
/// engine found associated with this user's onsets, when a model carrying
/// them beat the base model prospectively.
///
/// Column names are the metric's raw column name plus a suffix, so
/// `CorrelationFeature.matching(mlFeatureName:)` folds them back onto their
/// parent feature for importances and attribution. Missing values default to
/// 0 here but are median-imputed upstream, so that default is never scored.
class TemporalContextInput: MLFeatureProvider {

  /// One window statistic.
  enum Statistic: CaseIterable {
    case mean24h
    case delta24h
    case range48h
    case range72h
    case delta6h

    /// The column-name suffix.
    var suffix: String {
      switch self {
      case .mean24h: return " 24h Mean"
      case .delta24h: return " 24h Delta"
      case .range48h: return " 48h Range"
      case .range72h: return " 72h Range"
      case .delta6h: return " 6h Delta"
      }
    }

    /// The statistic's value.
    func value(in statistics: WindowStatistics) -> Double? {
      switch self {
      case .mean24h: return statistics.mean24h
      case .delta24h: return statistics.delta24h
      case .range48h: return statistics.range48h
      case .range72h: return statistics.range72h
      case .delta6h: return statistics.delta6h
      }
    }
  }

  /// The statistics emitted for every window metric.
  static let baseStatistics: [Statistic] = [.delta24h, .range48h]

  /// The statistics emitted only for personalized features.
  static let personalizedStatistics: [Statistic] = [.mean24h, .range72h, .delta6h]

  /// Every suffix, for column-name matching.
  static let suffixes = Statistic.allCases.map({ $0.suffix })

  /// The raw column name each health window metric extends.
  static let healthBaseName: [HealthKitData: String] = [
    .heartRate: UncontrolledUserInput.FeatureName.heartRate,
    .heartRateVariabilitySDNN: UncontrolledUserInput.FeatureName.heartRateVariability,
    .respiratoryRate: UncontrolledUserInput.FeatureName.respiratoryRate,
    .oxygenSaturation: UncontrolledUserInput.FeatureName.oxygenSaturation,
    .bodyTemperature: UncontrolledUserInput.FeatureName.bodyTemperature,
    .environmentalAudioExposure: EnvironmentalInput.FeatureName.environmentAudioExposure,
    .headphoneAudioExposure: ControlledUserInput.FeatureName.headphoneAudioExposure,
    .restingHeartRate: UncontrolledUserInput.FeatureName.restingHeartRate,
    .walkingHeartRateAverage: UncontrolledUserInput.FeatureName.walkingHeartRateAverage,
    .wristTemperature: UncontrolledUserInput.FeatureName.wristTemperature,
    .basalBodyTemperature: UncontrolledUserInput.FeatureName.basalBodyTemperature,
    .stepCount: ControlledUserInput.FeatureName.stepCount
  ]

  /// The raw column name each weather window field extends.
  static let weatherBaseName: [WeatherField: String] = [
    .currentPressure: EnvironmentalInput.FeatureName.currentPressure,
    .humidity: EnvironmentalInput.FeatureName.currentHumidity,
    .temperature: EnvironmentalInput.FeatureName.currentTemperature
  ]

  /// The column name for a health metric's statistic.
  static func featureName(_ metric: HealthKitData, _ statistic: Statistic) -> String? {
    guard let base = healthBaseName[metric] else {
      return nil
    }
    return base + statistic.suffix
  }

  /// The column name for a weather field's statistic.
  static func featureName(_ field: WeatherField, _ statistic: Statistic) -> String? {
    guard let base = weatherBaseName[field] else {
      return nil
    }
    return base + statistic.suffix
  }

  /// The columns (with their values) this provider emits for the given
  /// personalized features: the base statistics for every enabled window
  /// metric, plus the extended statistics for personalized ones.
  ///
  /// - Parameters:
  ///   - preferences: The predictor preferences.
  ///   - personalized: The features promoted by personalization.
  /// - Returns: The column names.
  static func columnNames(preferences: Preferences.Predictors, personalized: Set<CorrelationFeature>) -> Set<String> {
    guard preferences.temporalContext else {
      return []
    }

    var names = Set<String>()
    for metric in HealthKitData.windowMetrics where preferences.isModelled(metric) {
      var statistics = baseStatistics
      if let feature = CorrelationFeature(healthKitData: metric), personalized.contains(feature) {
        statistics += personalizedStatistics
      }
      for statistic in statistics {
        if let name = featureName(metric, statistic) {
          names.insert(name)
        }
      }
    }
    for field in WeatherField.windowFields where preferences.isModelled(field) {
      var statistics = baseStatistics
      if personalized.contains(field.correlationFeature) {
        statistics += personalizedStatistics
      }
      for statistic in statistics {
        if let name = featureName(field, statistic) {
          names.insert(name)
        }
      }
    }
    return names
  }

  // MARK: Instance

  private let preferences = Preferences.Predictors()

  /// The values keyed by column name.
  private let values: [String: Double]

  /// The columns to emit.
  private let names: Set<String>

  init(health: [HealthKitData: WindowStatistics]?, weather: [WeatherField: WindowStatistics]?, personalized: Set<CorrelationFeature>?) {
    var values = [String: Double]()
    for (metric, statistics) in health ?? [:] {
      for statistic in Statistic.allCases {
        if let name = TemporalContextInput.featureName(metric, statistic), let value = statistic.value(in: statistics) {
          values[name] = value
        }
      }
    }
    for (field, statistics) in weather ?? [:] {
      for statistic in Statistic.allCases {
        if let name = TemporalContextInput.featureName(field, statistic), let value = statistic.value(in: statistics) {
          values[name] = value
        }
      }
    }
    self.values = values
    names = TemporalContextInput.columnNames(preferences: preferences, personalized: personalized ?? [])
  }

  var featureNames: Set<String> {
    return names
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    guard names.contains(featureName) else {
      return nil
    }
    return MLFeatureValue(double: values[featureName] ?? 0.0)
  }

}
