//
//  BaselineFeatures.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/17/26.
//

import Foundation

/// The autonomic metrics fed to the model as personal-baseline-relative
/// features (rolling z-scores, and short-window slopes in a later step).
///
/// The migraine prodrome is a shift against the person's *own* rolling
/// baseline — an HRV drop or a skin-temperature rise that only reads as
/// abnormal relative to their usual. Raw windowed values under-carry that
/// signal, so these metrics are additionally standardized against a causal
/// (past-only) 14-day personal baseline.
enum BaselineFeatures {

  /// The metrics standardized against a personal baseline.
  static let metrics: [HealthKitData] = [
    .heartRateVariabilitySDNN,
    .restingHeartRate,
    .respiratoryRate,
    .sleepSeconds,
    .bodyTemperature,
    .wristTemperature,
    .basalBodyTemperature,
    .hrvRMSSD,
    .hrvPNN50,
    .hrvLFHF
  ]

  /// The nominal lookback for a short-window slope (change over ~6 hours,
  /// where autonomic precursors are strongest).
  static let slopeGap: TimeInterval = 6.0 * 3600.0

  /// The minimum acceptable gap to a prior sample when forming a slope.
  static let slopeMinGap: TimeInterval = 2.0 * 3600.0

  /// The maximum acceptable gap to a prior sample when forming a slope.
  static let slopeMaxGap: TimeInterval = 12.0 * 3600.0

  /// Attaches causal baseline-relative features — rolling z-scores and
  /// short-window slopes — to a chronologically sorted series of inputs.
  ///
  /// Each row's z-score is computed from that row's trailing 14 days only
  /// (the current value excluded), and its slope is the change in that causal
  /// z-score versus the sample nearest `slopeGap` earlier. No future
  /// information leaks into a row's features — the invariant that makes
  /// within-subject validation honest. Rows lacking history (or the raw
  /// metric) get no feature and fall back to the provider's neutral default.
  ///
  /// - Parameter inputs: The inputs, sorted oldest-first.
  /// - Returns: The same inputs with `baselineZ`/`baselineSlope` populated
  ///   where derivable.
  static func attachingBaselineFeatures(to inputs: [ModelInput]) -> [ModelInput] {
    var result = inputs

    for metric in metrics {
      // The present (timestamp, value) samples for this metric, in order.
      var indices = [Int]()
      var values = [Double]()
      var timestamps = [Date]()
      for (index, input) in inputs.enumerated() {
        guard let value = input.healthKitData?[metric] else {
          continue
        }
        indices.append(index)
        values.append(value)
        timestamps.append(input.date)
      }

      guard !values.isEmpty else {
        continue
      }

      let zScores = CorrelationMath.rollingZScores(values: values, timestamps: timestamps)

      // Retain the rows that got a z-score, in time order, for slope pairing.
      var zEntries = [(rowIndex: Int, time: Date, z: Double)]()
      for (offset, rowIndex) in indices.enumerated() {
        guard let z = zScores[offset] else {
          continue
        }
        var baseline = result[rowIndex].baselineZ ?? [:]
        baseline[metric] = z
        result[rowIndex].baselineZ = baseline
        zEntries.append((rowIndex, timestamps[offset], z))
      }

      // Slope: change in causal z versus the prior z-sample nearest `slopeGap`.
      for k in zEntries.indices {
        let current = zEntries[k]
        var bestIndex: Int?
        var bestError = Double.greatestFiniteMagnitude
        var m = k - 1
        while m >= 0 {
          let gap = current.time.timeIntervalSince(zEntries[m].time)
          if gap > slopeMaxGap {
            break
          }
          if gap >= slopeMinGap {
            let error = abs(gap - slopeGap)
            if error < bestError {
              bestError = error
              bestIndex = m
            }
          }
          m -= 1
        }

        guard let priorIndex = bestIndex else {
          continue
        }
        var slope = result[current.rowIndex].baselineSlope ?? [:]
        slope[metric] = current.z - zEntries[priorIndex].z
        result[current.rowIndex].baselineSlope = slope
      }
    }

    return result
  }

}

/// Per-metric personal baselines (mean/std over a trailing window), persisted
/// beside the model so inference standardizes a live reading against the same
/// recent baseline the model was trained against.
///
/// Training rows each use their own *rolling* baseline (see
/// `BaselineFeatures.attachingZScores`); this frozen snapshot is the single
/// most-recent baseline used at prediction time, refreshed on every retrain.
struct FeatureBaselines: Codable {

  /// A single metric's baseline.
  struct Baseline: Codable {
    let mean: Double
    let std: Double
    let count: Int
  }

  /// The winsorization limit, matching `CorrelationMath.rollingZScores`.
  private static let zLimit = 6.0

  /// The trailing window over which a baseline is computed.
  static let window: TimeInterval = 14.0 * 86400.0

  /// The minimum present samples required to form a baseline, matching
  /// `CorrelationMath.rollingZScores`'s `minimumCount`.
  static let minimumCount = 5

  /// The per-metric baselines.
  var byMetric = [HealthKitData: Baseline]()

  // MARK: Static methods

  /// Computes the most-recent per-metric baseline from a chronologically
  /// sorted series.
  ///
  /// For each metric, the mean and (population) standard deviation are taken
  /// over the present samples falling in the trailing `window` ending at
  /// `asOf` — i.e. what `rollingZScores` would use as the baseline for a new
  /// sample appended just after the series.
  ///
  /// - Parameters:
  ///   - inputs: The inputs, sorted oldest-first.
  ///   - asOf: The end of the trailing window; defaults to the last input's date.
  /// - Returns: The computed baselines.
  static func computed(from inputs: [ModelInput], asOf: Date? = nil) -> FeatureBaselines {
    var baselines = FeatureBaselines()

    guard let end = asOf ?? inputs.last?.date else {
      return baselines
    }
    let start = end.addingTimeInterval(-window)

    for metric in BaselineFeatures.metrics {
      let values: [Double] = inputs.compactMap { input in
        guard input.date >= start, input.date <= end else {
          return nil
        }
        return input.healthKitData?[metric]
      }

      guard values.count >= minimumCount else {
        continue
      }

      let mean = values.reduce(0.0, +) / Double(values.count)
      let variance = values.reduce(0.0, { $0 + ($1 - mean) * ($1 - mean) }) / Double(values.count)
      let std = variance.squareRoot()
      guard std > 0.0 else {
        continue
      }

      baselines.byMetric[metric] = Baseline(mean: mean, std: std, count: values.count)
    }

    return baselines
  }

  // MARK: Public methods

  /// The winsorized z-score of a live value against this metric's baseline,
  /// or nil when no baseline exists.
  ///
  /// - Parameters:
  ///   - value: The raw value.
  ///   - metric: The metric.
  /// - Returns: The z-score, clamped to ±6, or nil.
  func zScore(of value: Double, for metric: HealthKitData) -> Double? {
    guard let baseline = byMetric[metric], baseline.std > 0.0 else {
      return nil
    }
    let z = (value - baseline.mean) / baseline.std
    return min(max(z, -Self.zLimit), Self.zLimit)
  }

  /// The baseline-relative z-scores for a live reading, computed only for the
  /// present metrics that have a baseline.
  ///
  /// - Parameter healthKitData: The raw reading.
  /// - Returns: The z-scores per metric.
  func zScores(for healthKitData: [HealthKitData: Double]?) -> [HealthKitData: Double] {
    guard let healthKitData = healthKitData else {
      return [:]
    }

    var zScores = [HealthKitData: Double]()
    for metric in BaselineFeatures.metrics {
      guard let value = healthKitData[metric], let z = zScore(of: value, for: metric) else {
        continue
      }
      zScores[metric] = z
    }
    return zScores
  }

  /// The baseline-relative slopes for a live reading: the change in each
  /// metric's z-score versus a reading from ~`slopeGap` earlier, both
  /// standardized against this frozen baseline.
  ///
  /// - Parameters:
  ///   - current: The current raw reading.
  ///   - previous: The raw reading from ~`BaselineFeatures.slopeGap` earlier.
  /// - Returns: The slopes per metric, for metrics present in both readings.
  func slopes(current: [HealthKitData: Double]?, previous: [HealthKitData: Double]?) -> [HealthKitData: Double] {
    guard let current = current, let previous = previous else {
      return [:]
    }

    var slopes = [HealthKitData: Double]()
    for metric in BaselineFeatures.metrics {
      guard let currentValue = current[metric], let previousValue = previous[metric],
            let currentZ = zScore(of: currentValue, for: metric),
            let previousZ = zScore(of: previousValue, for: metric) else {
        continue
      }
      slopes[metric] = currentZ - previousZ
    }
    return slopes
  }

}
