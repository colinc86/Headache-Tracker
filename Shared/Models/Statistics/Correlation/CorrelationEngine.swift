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
    }

    var candidates = [Candidate]()
    var maxPairCounts = [CorrelationFeature: Int]()

    // MARK: Occurrence target

    for feature in CorrelationFeature.allCases {
      var lagProfile = [Int: Double]()
      var best: (lag: Int, coefficient: Double, x: [Double], target: [Bool])?

      for lag in Self.lagsHours {
        let horizon = TimeInterval(lag) * 3600.0

        var x = [Double]()
        var target = [Bool]()
        for sample in baselineSamples {
          guard let value = sample.values[feature] else {
            continue
          }
          let hasUpcomingOnset = onsets.contains(where: { onset in
            onset > sample.timestamp && onset.timeIntervalSince(sample.timestamp) <= horizon
          })
          x.append(value)
          target.append(hasUpcomingOnset)
        }

        maxPairCounts[feature] = max(maxPairCounts[feature] ?? 0, x.count)

        let eventCount = target.lazy.filter({ $0 }).count
        guard x.count >= Self.minimumSampleCount,
              eventCount >= Self.minimumEventCount,
              let coefficient = CorrelationMath.pointBiserial(x, target) else {
          continue
        }

        lagProfile[lag] = coefficient
        if best == nil || abs(coefficient) > abs(best!.coefficient) {
          best = (lag, coefficient, x, target)
        }
      }

      if let best = best {
        let y = best.target.map({ $0 ? 1.0 : 0.0 })
        let pValue = CorrelationMath.circularShiftPValue(coefficient: best.coefficient, x: best.x, y: y)
        let positive = zip(best.x, best.target).filter({ $0.1 }).map({ $0.0 })
        let baseline = zip(best.x, best.target).filter({ !$0.1 }).map({ $0.0 })

        candidates.append(Candidate(
          feature: feature,
          target: .occurrence,
          coefficient: best.coefficient,
          pValue: pValue,
          bestLagHours: best.lag,
          lagProfile: lagProfile,
          sampleCount: best.x.count,
          eventCount: positive.count,
          positiveMean: positive.isEmpty ? 0.0 : positive.reduce(0.0, +) / Double(positive.count),
          baselineMean: baseline.isEmpty ? 0.0 : baseline.reduce(0.0, +) / Double(baseline.count)))
      }
    }

    // MARK: Severity target

    for feature in CorrelationFeature.allCases {
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
        baselineMean: baseline.isEmpty ? 0.0 : baseline.reduce(0.0, +) / Double(baseline.count)))
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
        baselineMean: candidate.baselineMean)
    }

    insights.sort { lhs, rhs in
      if lhs.confidence != rhs.confidence {
        return lhs.confidence < rhs.confidence
      }
      return abs(lhs.coefficient) > abs(rhs.coefficient)
    }

    let measured = Set(insights.map({ $0.feature }))
    let insufficient = CorrelationFeature.allCases
      .filter({ !measured.contains($0) })
      .map({ InsightsReport.InsufficientFeature(feature: $0, sampleCount: maxPairCounts[$0] ?? 0) })

    return InsightsReport(
      generatedAt: Date(),
      rowCount: samples.count,
      insights: insights,
      insufficient: insufficient)
  }

}
