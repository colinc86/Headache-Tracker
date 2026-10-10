//
//  ContextData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import CoreData
import Foundation

/// Which window metrics carry a mean (bit set) in a `ContextData` row. Ranges
/// need two buckets, so they have their own mask. Bits 0–11 are the health
/// window metrics in `HealthKitData.windowMetrics` order; bits 16–18 are the
/// weather fields in `WeatherField.windowFields` order.
struct ContextMetricPresence: OptionSet {

  let rawValue: Int64

  init(rawValue: Int64) {
    self.rawValue = rawValue
  }

  /// The bit for a health window metric.
  init?(_ metric: HealthKitData) {
    guard let index = HealthKitData.windowMetrics.firstIndex(of: metric) else {
      return nil
    }
    self.init(rawValue: 1 << Int64(index))
  }

  /// The bit for a weather window field.
  init?(_ field: WeatherField) {
    guard let index = WeatherField.windowFields.firstIndex(of: field) else {
      return nil
    }
    self.init(rawValue: 1 << Int64(16 + index))
  }

}

extension ContextData {

  /// The stored statistic suffixes, matching the `ContextData` attribute
  /// names `<base><Suffix>`.
  private enum Suffix: String, CaseIterable {
    case mean24h = "Mean24h"
    case delta24h = "Delta24h"
    case range48h = "Range48h"
    case range72h = "Range72h"
    case delta6h = "Delta6h"
  }

  /// The metrics whose mean is present.
  var presence: ContextMetricPresence {
    return ContextMetricPresence(rawValue: presentMetrics)
  }

  /// The metrics whose ranges are present.
  var rangePresence: ContextMetricPresence {
    return ContextMetricPresence(rawValue: presentRanges)
  }

  /// The health window statistics that were actually computed.
  var healthWindowStatistics: [HealthKitData: WindowStatistics] {
    var result = [HealthKitData: WindowStatistics]()
    for metric in HealthKitData.windowMetrics {
      guard let base = metric.contextAttributeBase, let bit = ContextMetricPresence(metric) else {
        continue
      }
      if let statistics = readStatistics(base: base, meanPresent: presence.contains(bit), rangePresent: rangePresence.contains(bit)) {
        result[metric] = statistics
      }
    }
    return result
  }

  /// The weather window statistics that were actually computed.
  var weatherWindowStatistics: [WeatherField: WindowStatistics] {
    var result = [WeatherField: WindowStatistics]()
    for field in WeatherField.windowFields {
      guard let base = field.contextAttributeBase, let bit = ContextMetricPresence(field) else {
        continue
      }
      if let statistics = readStatistics(base: base, meanPresent: presence.contains(bit), rangePresent: rangePresence.contains(bit)) {
        result[field] = statistics
      }
    }
    return result
  }

  /// Updates the health half with window statistics.
  ///
  /// - Parameters:
  ///   - statistics: The statistics per metric; nil records that nothing was
  ///     read, so the row is retried by the next back-fill.
  ///   - timestamp: The row's timestamp.
  func updateWithHealthWindowStatistics(_ statistics: [HealthKitData: WindowStatistics]?, at timestamp: Date?) {
    var presence = self.presence
    var rangePresence = self.rangePresence
    for metric in HealthKitData.windowMetrics {
      guard let bit = ContextMetricPresence(metric), let base = metric.contextAttributeBase else {
        continue
      }
      presence.remove(bit)
      rangePresence.remove(bit)
      guard let value = statistics?[metric], !value.isEmpty else {
        continue
      }
      write(value, base: base)
      if value.mean24h != nil {
        presence.insert(bit)
      }
      if value.range48h != nil || value.range72h != nil {
        rangePresence.insert(bit)
      }
    }

    presentMetrics = presence.rawValue
    presentRanges = rangePresence.rawValue
    self.timestamp = timestamp
    healthVersion = statistics == nil ? nil : Constants.trainingDataContextVersion
  }

  /// Updates the weather half with window statistics.
  ///
  /// - Parameters:
  ///   - statistics: The statistics per field; nil records that nothing was
  ///     read.
  ///   - timestamp: The row's timestamp.
  func updateWithWeatherWindowStatistics(_ statistics: [WeatherField: WindowStatistics]?, at timestamp: Date?) {
    var presence = self.presence
    var rangePresence = self.rangePresence
    for field in WeatherField.windowFields {
      guard let bit = ContextMetricPresence(field), let base = field.contextAttributeBase else {
        continue
      }
      presence.remove(bit)
      rangePresence.remove(bit)
      guard let value = statistics?[field], !value.isEmpty else {
        continue
      }
      write(value, base: base)
      if value.mean24h != nil {
        presence.insert(bit)
      }
      if value.range48h != nil || value.range72h != nil {
        rangePresence.insert(bit)
      }
    }

    presentMetrics = presence.rawValue
    presentRanges = rangePresence.rawValue
    self.timestamp = timestamp
    weatherVersion = statistics == nil ? nil : Constants.trainingDataContextVersion
  }

  // MARK: Private

  /// Reads one metric's statistics from its five attributes, honouring the
  /// presence bits so an unset column never reads as a real zero.
  private func readStatistics(base: String, meanPresent: Bool, rangePresent: Bool) -> WindowStatistics? {
    guard meanPresent || rangePresent else {
      return nil
    }

    var statistics = WindowStatistics()
    if meanPresent {
      statistics.mean24h = value(forKey: base + Suffix.mean24h.rawValue) as? Double
      statistics.delta24h = value(forKey: base + Suffix.delta24h.rawValue) as? Double
      statistics.delta6h = value(forKey: base + Suffix.delta6h.rawValue) as? Double
    }
    if rangePresent {
      statistics.range48h = value(forKey: base + Suffix.range48h.rawValue) as? Double
      statistics.range72h = value(forKey: base + Suffix.range72h.rawValue) as? Double
    }
    return statistics
  }

  /// Writes one metric's statistics to its five attributes. A missing
  /// statistic is stored as nil so the column reads back as absent even when
  /// its presence bit is set for a sibling statistic.
  private func write(_ statistics: WindowStatistics, base: String) {
    setValue(statistics.mean24h, forKey: base + Suffix.mean24h.rawValue)
    setValue(statistics.delta24h, forKey: base + Suffix.delta24h.rawValue)
    setValue(statistics.delta6h, forKey: base + Suffix.delta6h.rawValue)
    setValue(statistics.range48h, forKey: base + Suffix.range48h.rawValue)
    setValue(statistics.range72h, forKey: base + Suffix.range72h.rawValue)
  }

}

extension WeatherField {

  /// The weather fields that get trailing-window context: the station
  /// readings with hourly history. Device pressure has none, and the sigma
  /// fields are already deltas.
  static let windowFields: [WeatherField] = [.currentPressure, .humidity, .temperature]

  /// Whether this field gets window context.
  var hasWindowStatistics: Bool {
    return WeatherField.windowFields.contains(self)
  }

  /// The base of this field's `ContextData` attribute names.
  var contextAttributeBase: String? {
    switch self {
    case .currentPressure: return "pressure"
    case .humidity: return "humidity"
    case .temperature: return "temperature"
    default: return nil
    }
  }

}
