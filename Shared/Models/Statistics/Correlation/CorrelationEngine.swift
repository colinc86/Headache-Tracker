//
//  CorrelationEngine.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// A value-type snapshot of one training data row for correlation analysis.
struct CorrelationSample {

  /// The sample's timestamp.
  let timestamp: Date

  /// The feature values that were actually measured for this sample.
  let values: [CorrelationFeature: Double]

}

/// A dated feature value for charting.
struct DatedValue: Identifiable {

  /// The value's date.
  let date: Date

  /// The value.
  let value: Double

  var id: Date {
    return date
  }

}

/// Computes per-feature associations between health/weather signals and
/// headaches. Pure value types and math — runs identically on the simulator
/// and device.
struct CorrelationEngine {

  /// Lead times (hours before onset) tested for the occurrence target.
  static let lagsHours = [6, 12, 24, 48]

  /// The minimum feature-target pairs required per test.
  static let minimumSampleCount = 30

  /// The minimum positive samples required per test.
  static let minimumEventCount = 10

  /// The samples to analyze.
  let samples: [CorrelationSample]

  /// The headache episodes to analyze against.
  let episodes: [HeadacheEpisode]

  /// The features to analyze — the predictors the user has left enabled.
  ///
  /// Injected rather than read from `Preferences` so the engine stays a pure,
  /// simulator-safe value type. A disabled feature is dropped from the report
  /// entirely: no insight *and* no "not enough data" entry, even though its
  /// historical values are still sitting in `TrainingData`.
  var enabledFeatures: Set<CorrelationFeature> = Set(CorrelationFeature.allCases)

  /// The enabled features in their canonical order.
  private var analyzedFeatures: [CorrelationFeature] {
    return CorrelationFeature.allCases.filter(enabledFeatures.contains)
  }

  /// Computes the full insights report.
  ///
  /// For each feature, headache *occurrence* is tested at several lead
  /// times: does the feature's value predict an onset within the next L
  /// hours? Samples taken during a headache are excluded from that target.
  /// *Severity* is tested with Spearman rank correlation against the
  /// severity in effect at each sample. All p-values come from
  /// autocorrelation-respecting circular-shift permutation and are
  /// FDR-adjusted across the whole feature-and-lag family.
  ///
  /// - Returns: The report.
  func computeReport() -> InsightsReport {
    let sortedSamples = samples.sorted(by: { $0.timestamp < $1.timestamp })
    let sortedEpisodes = episodes.sorted(by: { $0.start < $1.start })
    let onsets = sortedEpisodes.map({ $0.start })

    // Samples outside any episode, for the occurrence target.
    let baselineSamples = sortedSamples.filter { sample in
      !sortedEpisodes.contains(where: { $0.contains(sample.timestamp) })
    }

    struct Candidate {
      let feature: CorrelationFeature
      let target: TriggerInsight.Target
      let coefficient: Double
      let pValue: Double
      let bestLagHours: Int?
      let lagProfile: [Int: Double]
      let sampleCount: Int
      let eventCount: Int
      let positiveMean: Double
      let baselineMean: Double
      let usesBaselineRelative: Bool
    }

    var candidates = [Candidate]()
    var maxPairCounts = [CorrelationFeature: Int]()

    // MARK: Occurrence target

    // Per-feature series: personal-baseline z-scores when enough survive,
    // raw values otherwise. Raw values ride along for display means.
    var occurrenceSeries = [CorrelationFeature: FeatureSeries]()
    for feature in analyzedFeatures {
      if let series = CorrelationEngine.makeSeries(for: feature, from: baselineSamples) {
        occurrenceSeries[feature] = series
      }
    }

    let onsetWithin: (Date, TimeInterval) -> Bool = { timestamp, horizon in
      onsets.contains(where: { onset in
        onset > timestamp && onset.timeIntervalSince(timestamp) <= horizon
      })
    }

    for feature in analyzedFeatures {
      guard let series = occurrenceSeries[feature] else {
        continue
      }

      maxPairCounts[feature] = max(maxPairCounts[feature] ?? 0, series.values.count)

      var lagProfile = [Int: Double]()
      var best: (lag: Int, coefficient: Double, target: [Bool])?

      for lag in Self.lagsHours {
        let horizon = TimeInterval(lag) * 3600.0
        let target = series.timestamps.map({ onsetWithin($0, horizon) })

        let eventCount = target.lazy.filter({ $0 }).count
        guard series.values.count >= Self.minimumSampleCount,
              eventCount >= Self.minimumEventCount,
              let coefficient = CorrelationMath.pointBiserial(series.values, target) else {
          continue
        }

        lagProfile[lag] = coefficient
        if best == nil || abs(coefficient) > abs(best!.coefficient) {
          best = (lag, coefficient, target)
        }
      }

      if let best = best {
        let y = best.target.map({ $0 ? 1.0 : 0.0 })
        let pValue = CorrelationMath.circularShiftPValue(coefficient: best.coefficient, x: series.values, y: y)

        // Display means stay in raw units regardless of the series type.
        let positive = zip(series.rawValues, best.target).filter({ $0.1 }).map({ $0.0 })
        let baseline = zip(series.rawValues, best.target).filter({ !$0.1 }).map({ $0.0 })

        candidates.append(Candidate(
          feature: feature,
          target: .occurrence,
          coefficient: best.coefficient,
          pValue: pValue,
          bestLagHours: best.lag,
          lagProfile: lagProfile,
          sampleCount: series.values.count,
          eventCount: positive.count,
          positiveMean: positive.isEmpty ? 0.0 : positive.reduce(0.0, +) / Double(positive.count),
          baselineMean: baseline.isEmpty ? 0.0 : baseline.reduce(0.0, +) / Double(baseline.count),
          usesBaselineRelative: series.usesBaselineRelative))
      }
    }

    // MARK: Severity target

    for feature in analyzedFeatures {
      var x = [Double]()
      var severities = [Double]()

      for sample in sortedSamples {
        guard let value = sample.values[feature] else {
          continue
        }
        let severity = sortedEpisodes.last(where: { $0.contains(sample.timestamp) })?.severity(at: sample.timestamp) ?? .notPresent
        x.append(value)
        severities.append(Double(severity.orderingValue))
      }

      maxPairCounts[feature] = max(maxPairCounts[feature] ?? 0, x.count)

      let eventCount = severities.lazy.filter({ $0 > 0.0 }).count
      guard x.count >= Self.minimumSampleCount,
            eventCount >= Self.minimumEventCount,
            let coefficient = CorrelationMath.spearman(x, severities) else {
        continue
      }

      let pValue = CorrelationMath.circularShiftPValue(coefficient: coefficient, x: x, y: severities, statistic: CorrelationMath.spearman)
      let positive = zip(x, severities).filter({ $0.1 > 0.0 }).map({ $0.0 })
      let baseline = zip(x, severities).filter({ $0.1 == 0.0 }).map({ $0.0 })

      candidates.append(Candidate(
        feature: feature,
        target: .severity,
        coefficient: coefficient,
        pValue: pValue,
        bestLagHours: nil,
        lagProfile: [:],
        sampleCount: x.count,
        eventCount: eventCount,
        positiveMean: positive.isEmpty ? 0.0 : positive.reduce(0.0, +) / Double(positive.count),
        baselineMean: baseline.isEmpty ? 0.0 : baseline.reduce(0.0, +) / Double(baseline.count),
        usesBaselineRelative: false))
    }

    // MARK: FDR adjustment and ranking

    let qValues = CorrelationMath.benjaminiHochberg(candidates.map({ $0.pValue }))
    var insights = zip(candidates, qValues).map { candidate, qValue in
      TriggerInsight(
        feature: candidate.feature,
        target: candidate.target,
        coefficient: candidate.coefficient,
        qValue: qValue,
        bestLagHours: candidate.bestLagHours,
        lagProfile: candidate.lagProfile,
        sampleCount: candidate.sampleCount,
        eventCount: candidate.eventCount,
        positiveMean: candidate.positiveMean,
        baselineMean: candidate.baselineMean,
        usesBaselineRelative: candidate.usesBaselineRelative,
        explainedBy: nil,
        partialCoefficient: nil)
    }

    insights.sort { lhs, rhs in
      if lhs.confidence != rhs.confidence {
        return lhs.confidence < rhs.confidence
      }
      return abs(lhs.coefficient) > abs(rhs.coefficient)
    }

    // MARK: Confounder pass

    // For each confident occurrence finding, check whether a strongly
    // co-correlated feature explains it: if the partial correlation
    // controlling for the confounder collapses, annotate the insight.
    for index in insights.indices {
      let insight = insights[index]
      guard insight.target == .occurrence,
            insight.confidence != .suggestive,
            let lag = insight.bestLagHours,
            let series = occurrenceSeries[insight.feature] else {
        continue
      }

      let horizon = TimeInterval(lag) * 3600.0
      var strongest: (feature: CorrelationFeature, partial: Double)?

      for (other, otherSeries) in occurrenceSeries where other != insight.feature {
        // Align the two series by timestamp.
        var otherByTime = [Date: Double]()
        for (timestamp, value) in zip(otherSeries.timestamps, otherSeries.values) {
          otherByTime[timestamp] = value
        }

        var xa = [Double]()
        var xb = [Double]()
        var y = [Double]()
        for (position, timestamp) in series.timestamps.enumerated() {
          guard let otherValue = otherByTime[timestamp] else {
            continue
          }
          xa.append(series.values[position])
          xb.append(otherValue)
          y.append(onsetWithin(timestamp, horizon) ? 1.0 : 0.0)
        }

        guard xa.count >= Self.minimumSampleCount,
              let coCorrelation = CorrelationMath.pearson(xa, xb),
              abs(coCorrelation) >= 0.5,
              let original = CorrelationMath.pearson(xa, y) else {
          continue
        }

        // Near-perfect collinearity breaks the partial's closed form; the
        // two signals are then indistinguishable, which is the strongest
        // possible "explained by".
        let partial: Double
        if abs(coCorrelation) >= 0.99 {
          partial = 0.0
        }
        else if let computed = CorrelationMath.partial(xa, y, controlling: xb) {
          partial = computed
        }
        else {
          continue
        }

        if abs(partial) < 0.5 * abs(original) {
          if strongest == nil || abs(partial) < abs(strongest!.partial) {
            strongest = (other, partial)
          }
        }
      }

      if let strongest = strongest {
        insights[index] = TriggerInsight(
          feature: insight.feature,
          target: insight.target,
          coefficient: insight.coefficient,
          qValue: insight.qValue,
          bestLagHours: insight.bestLagHours,
          lagProfile: insight.lagProfile,
          sampleCount: insight.sampleCount,
          eventCount: insight.eventCount,
          positiveMean: insight.positiveMean,
          baselineMean: insight.baselineMean,
          usesBaselineRelative: insight.usesBaselineRelative,
          explainedBy: strongest.feature,
          partialCoefficient: strongest.partial)
      }
    }

    let measured = Set(insights.map({ $0.feature }))
    let insufficient = analyzedFeatures
      .filter({ !measured.contains($0) })
      .map({ InsightsReport.InsufficientFeature(feature: $0, sampleCount: maxPairCounts[$0] ?? 0) })

    return InsightsReport(
      generatedAt: Date(),
      rowCount: samples.count,
      insights: insights,
      insufficient: insufficient,
      baselines: CorrelationEngine.baselines(from: sortedSamples, enabledFeatures: enabledFeatures),
      schemaVersion: InsightsReport.currentSchemaVersion,
      enabledFingerprint: InsightsReport.fingerprint(for: enabledFeatures))
  }

  // MARK: Series and baselines

  /// A feature's time-ordered series for the occurrence target.
  struct FeatureSeries {

    /// The timestamps of the retained samples.
    let timestamps: [Date]

    /// The values used for correlation: z-scores when enough survive, raw
    /// values otherwise.
    let values: [Double]

    /// The raw values aligned with `timestamps`, for display means.
    let rawValues: [Double]

    /// Whether `values` are personal-baseline z-scores.
    let usesBaselineRelative: Bool

  }

  /// Builds a feature's occurrence series, preferring personal-baseline
  /// z-scores over raw values when enough trailing history exists.
  ///
  /// - Parameters:
  ///   - feature: The feature.
  ///   - samples: The (time-ordered) out-of-headache samples.
  /// - Returns: The series, or nil when the feature never appears.
  static func makeSeries(for feature: CorrelationFeature, from samples: [CorrelationSample]) -> FeatureSeries? {
    var timestamps = [Date]()
    var raw = [Double]()
    for sample in samples {
      if let value = sample.values[feature] {
        timestamps.append(sample.timestamp)
        raw.append(value)
      }
    }

    guard !raw.isEmpty else {
      return nil
    }

    let zScores = CorrelationMath.rollingZScores(values: raw, timestamps: timestamps)
    let retained = zScores.indices.filter({ zScores[$0] != nil })

    if retained.count >= Self.minimumSampleCount {
      return FeatureSeries(
        timestamps: retained.map({ timestamps[$0] }),
        values: retained.map({ zScores[$0]! }),
        rawValues: retained.map({ raw[$0] }),
        usesBaselineRelative: true)
    }

    return FeatureSeries(timestamps: timestamps, values: raw, rawValues: raw, usesBaselineRelative: false)
  }

  /// Per-feature trailing-14-day baselines at report time, for the morning
  /// brief's "vs. your usual" comparisons.
  ///
  /// - Parameters:
  ///   - samples: The time-ordered samples.
  ///   - window: The trailing window.
  ///   - enabledFeatures: The features to baseline; disabled predictors are
  ///     skipped so they can't reappear in the morning brief's "vs. your
  ///     usual" comparisons by way of `RiskBriefBuilder`.
  /// - Returns: Baselines for features with at least three recent values.
  static func baselines(
    from samples: [CorrelationSample],
    window: TimeInterval = 14.0 * 86400.0,
    enabledFeatures: Set<CorrelationFeature> = Set(CorrelationFeature.allCases)
  ) -> [CorrelationFeature: FeatureBaseline] {
    guard let latest = samples.last?.timestamp else {
      return [:]
    }

    let cutoff = latest.addingTimeInterval(-window)
    var valuesByFeature = [CorrelationFeature: [Double]]()
    for sample in samples where sample.timestamp >= cutoff {
      for (feature, value) in sample.values where enabledFeatures.contains(feature) {
        valuesByFeature[feature, default: []].append(value)
      }
    }

    var baselines = [CorrelationFeature: FeatureBaseline]()
    for (feature, values) in valuesByFeature where values.count >= 3 {
      let mean = values.reduce(0.0, +) / Double(values.count)
      let variance = values.reduce(0.0, { $0 + ($1 - mean) * ($1 - mean) }) / Double(values.count)
      baselines[feature] = FeatureBaseline(mean: mean, std: sqrt(variance), count: values.count)
    }

    return baselines
  }

}
