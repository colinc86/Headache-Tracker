//
//  ClassificationMetrics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// Ranking and probability metrics for a binary classifier, plus a cluster
/// bootstrap for confidence intervals. Pure math; simulator-safe.
enum ClassificationMetrics {

  /// A two-sided confidence interval.
  struct Interval: Codable, Equatable {
    let lower: Double
    let upper: Double
  }

  /// The area under the ROC curve, computed as the Mann–Whitney statistic
  /// with average ranks for ties.
  ///
  /// - Parameters:
  ///   - scores: The scores, higher meaning more likely positive.
  ///   - outcomes: The outcomes aligned with `scores`.
  /// - Returns: The AUC, or nil without at least one positive and one
  ///   negative.
  static func auc(scores: [Double], outcomes: [Bool]) -> Double? {
    guard scores.count == outcomes.count, !scores.isEmpty else {
      return nil
    }

    let positives = outcomes.lazy.filter({ $0 }).count
    let negatives = outcomes.count - positives
    guard positives > 0, negatives > 0 else {
      return nil
    }

    // Average ranks (1-based) over tied scores.
    let order = scores.indices.sorted(by: { scores[$0] < scores[$1] })
    var ranks = [Double](repeating: 0.0, count: scores.count)
    var start = 0
    while start < order.count {
      var end = start
      while end + 1 < order.count && scores[order[end + 1]] == scores[order[start]] {
        end += 1
      }
      let averageRank = Double(start + end + 2) / 2.0
      for position in start ... end {
        ranks[order[position]] = averageRank
      }
      start = end + 1
    }

    var positiveRankSum = 0.0
    for (rank, outcome) in zip(ranks, outcomes) where outcome {
      positiveRankSum += rank
    }

    let u = positiveRankSum - Double(positives) * Double(positives + 1) / 2.0
    return u / (Double(positives) * Double(negatives))
  }

  /// The mean log loss of probabilities against outcomes.
  ///
  /// - Parameters:
  ///   - probabilities: The predicted positive probabilities.
  ///   - outcomes: The outcomes aligned with `probabilities`.
  ///   - epsilon: The clamp keeping the log finite.
  /// - Returns: The log loss, or nil when empty.
  static func logLoss(probabilities: [Double], outcomes: [Bool], epsilon: Double = 1e-6) -> Double? {
    guard probabilities.count == outcomes.count, !probabilities.isEmpty else {
      return nil
    }

    var total = 0.0
    for (probability, outcome) in zip(probabilities, outcomes) {
      let p = min(max(probability, epsilon), 1.0 - epsilon)
      total -= outcome ? log(p) : log(1.0 - p)
    }
    return total / Double(probabilities.count)
  }

  /// The accuracy of thresholded probabilities.
  ///
  /// - Parameters:
  ///   - probabilities: The predicted positive probabilities.
  ///   - outcomes: The outcomes aligned with `probabilities`.
  ///   - threshold: The positive threshold.
  /// - Returns: The accuracy, or nil when empty.
  static func accuracy(probabilities: [Double], outcomes: [Bool], threshold: Double = 0.5) -> Double? {
    guard probabilities.count == outcomes.count, !probabilities.isEmpty else {
      return nil
    }

    let correct = zip(probabilities, outcomes).lazy.filter({ ($0.0 >= threshold) == $0.1 }).count
    return Double(correct) / Double(probabilities.count)
  }

  /// A cluster bootstrap: clusters are resampled with replacement and their
  /// rows pooled, so rows that share a label-generating event (the same
  /// upcoming headache) move together. Rows resampled independently would
  /// understate the interval badly at ~20 episodes.
  ///
  /// - Parameters:
  ///   - clusters: The cluster identifier of each row.
  ///   - resamples: The number of bootstrap resamples.
  ///   - seed: The generator seed, for reproducibility.
  ///   - level: The confidence level.
  ///   - statistic: Computes the statistic over the given row indices (with
  ///     repeats); nil when undefined for that resample.
  /// - Returns: The percentile interval and the resample values, or nil when
  ///   fewer than two clusters exist or no resample produced a value.
  static func clusterBootstrap(
    clusters: [AnyHashable],
    resamples: Int = 200,
    seed: UInt64 = 42,
    level: Double = 0.95,
    statistic: ([Int]) -> Double?
  ) -> (interval: Interval, samples: [Double])? {
    let samples = clusterResamples(clusters: clusters, resamples: resamples, seed: seed).compactMap(statistic)
    guard !samples.isEmpty else {
      return nil
    }

    let alpha = (1.0 - level) / 2.0
    return (Interval(lower: percentile(samples, alpha), upper: percentile(samples, 1.0 - alpha)), samples)
  }

  /// A paired cluster bootstrap: the same cluster resamples are fed to a
  /// statistic that scores two models, and the per-resample differences
  /// (first minus second) are returned.
  ///
  /// - Parameters:
  ///   - clusters: The cluster identifier of each row.
  ///   - resamples: The number of bootstrap resamples.
  ///   - seed: The generator seed.
  ///   - statistic: Computes both statistics over the row indices.
  /// - Returns: The differences, one per resample that produced values.
  static func pairedClusterBootstrap(
    clusters: [AnyHashable],
    resamples: Int = 200,
    seed: UInt64 = 42,
    statistic: ([Int]) -> (Double, Double)?
  ) -> [Double] {
    return clusterResamples(clusters: clusters, resamples: resamples, seed: seed).compactMap { indices in
      guard let (first, second) = statistic(indices) else {
        return nil
      }
      return first - second
    }
  }

  /// The value at a quantile of the samples (linear interpolation).
  ///
  /// - Parameters:
  ///   - samples: The samples.
  ///   - quantile: The quantile in [0, 1].
  /// - Returns: The value.
  static func percentile(_ samples: [Double], _ quantile: Double) -> Double {
    let sorted = samples.sorted()
    guard sorted.count > 1 else {
      return sorted.first ?? .nan
    }

    let position = min(max(quantile, 0.0), 1.0) * Double(sorted.count - 1)
    let lower = Int(position.rounded(.down))
    let upper = min(lower + 1, sorted.count - 1)
    let fraction = position - Double(lower)
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
  }

  // MARK: Resampling

  /// Row-index resamples formed by drawing clusters with replacement: each
  /// resample draws as many clusters as exist and pools their rows (with
  /// repeats). Shared by the bootstrap intervals and the bagged ensemble.
  ///
  /// - Parameters:
  ///   - clusters: The cluster identifier of each row.
  ///   - resamples: The number of resamples.
  ///   - seed: The generator seed, for reproducibility.
  /// - Returns: The resamples, or `[]` with fewer than two clusters.
  static func clusterResamples(clusters: [AnyHashable], resamples: Int, seed: UInt64) -> [[Int]] {
    var rowsByCluster = [AnyHashable: [Int]]()
    var clusterOrder = [AnyHashable]()
    for (index, cluster) in clusters.enumerated() {
      if rowsByCluster[cluster] == nil {
        clusterOrder.append(cluster)
      }
      rowsByCluster[cluster, default: []].append(index)
    }

    guard clusterOrder.count >= 2 else {
      return []
    }

    var generator = CorrelationMath.SeededGenerator(seed: seed)
    var result = [[Int]]()
    result.reserveCapacity(resamples)
    for _ in 0 ..< resamples {
      var indices = [Int]()
      for _ in 0 ..< clusterOrder.count {
        let pick = clusterOrder[Int.random(in: 0 ..< clusterOrder.count, using: &generator)]
        indices.append(contentsOf: rowsByCluster[pick] ?? [])
      }
      result.append(indices)
    }
    return result
  }

}
