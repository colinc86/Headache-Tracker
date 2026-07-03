//
//  CorrelationMath.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation
import Surge

/// Statistical primitives for the correlation engine.
struct CorrelationMath {

  /// A deterministic pseudorandom generator (SplitMix64) so permutation
  /// tests are reproducible.
  struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
      state = seed
    }

    mutating func next() -> UInt64 {
      state &+= 0x9E3779B97F4A7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
      z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
      return z ^ (z >> 31)
    }
  }

  /// The Pearson correlation coefficient between two equal-length arrays,
  /// or nil when either array is constant or too short.
  ///
  /// - Parameters:
  ///   - x: The first array.
  ///   - y: The second array.
  /// - Returns: A coefficient in [-1, 1].
  static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
    guard x.count == y.count, x.count >= 2 else {
      return nil
    }

    let meanX = Surge.mean(x)
    let meanY = Surge.mean(y)
    let deltaX = Surge.add(x, -meanX)
    let deltaY = Surge.add(y, -meanY)
    let normX = sqrt(Surge.dot(deltaX, deltaX))
    let normY = sqrt(Surge.dot(deltaY, deltaY))

    guard normX > 0.0, normY > 0.0 else {
      return nil
    }

    return Surge.dot(deltaX, deltaY) / (normX * normY)
  }

  /// The point-biserial correlation between a continuous array and a binary
  /// target. Equivalent to Pearson against a 0/1 encoding.
  ///
  /// - Parameters:
  ///   - x: The continuous values.
  ///   - target: The binary target.
  /// - Returns: A coefficient in [-1, 1].
  static func pointBiserial(_ x: [Double], _ target: [Bool]) -> Double? {
    return pearson(x, target.map({ $0 ? 1.0 : 0.0 }))
  }

  /// Tie-aware fractional ranks (average ranks for ties), 1-based.
  ///
  /// - Parameter values: The values to rank.
  /// - Returns: The ranks in the original order.
  static func ranks(_ values: [Double]) -> [Double] {
    let sortedIndices = values.indices.sorted(by: { values[$0] < values[$1] })
    var ranks = [Double](repeating: 0.0, count: values.count)

    var i = 0
    while i < sortedIndices.count {
      var j = i
      while j + 1 < sortedIndices.count && values[sortedIndices[j + 1]] == values[sortedIndices[i]] {
        j += 1
      }

      // Average rank of the tie group.
      let rank = Double(i + j) / 2.0 + 1.0
      for k in i ... j {
        ranks[sortedIndices[k]] = rank
      }
      i = j + 1
    }

    return ranks
  }

  /// Spearman's rank correlation coefficient.
  ///
  /// - Parameters:
  ///   - x: The first array.
  ///   - y: The second array.
  /// - Returns: A coefficient in [-1, 1].
  static func spearman(_ x: [Double], _ y: [Double]) -> Double? {
    guard x.count == y.count, x.count >= 2 else {
      return nil
    }
    return pearson(ranks(x), ranks(y))
  }

  /// A permutation p-value for an observed correlation between time-ordered
  /// arrays, using random circular shifts of the target. Shifting preserves
  /// each series' serial autocorrelation, which naive shuffling would break
  /// and thereby overstate significance.
  ///
  /// - Parameters:
  ///   - coefficient: The observed correlation.
  ///   - x: The time-ordered feature values.
  ///   - y: The time-ordered target values.
  ///   - statistic: Computes the correlation between two arrays.
  ///   - iterations: The number of random shifts to test.
  ///   - seed: The generator seed.
  /// - Returns: A p-value in (0, 1].
  static func circularShiftPValue(
    coefficient: Double,
    x: [Double],
    y: [Double],
    statistic: ([Double], [Double]) -> Double? = pearson,
    iterations: Int = 500,
    seed: UInt64 = 0x5EED
  ) -> Double {
    guard x.count == y.count, x.count > 2 else {
      return 1.0
    }

    var generator = SeededGenerator(seed: seed)
    let threshold = abs(coefficient)
    var extremeCount = 0

    for _ in 0 ..< iterations {
      let offset = Int.random(in: 1 ..< y.count, using: &generator)
      let shifted = [Double](y[offset...] + y[..<offset])
      if let r = statistic(x, shifted), abs(r) >= threshold {
        extremeCount += 1
      }
    }

    return Double(extremeCount + 1) / Double(iterations + 1)
  }

  /// Rolling personal-baseline z-scores over a trailing window.
  ///
  /// Each value is standardized against the mean and standard deviation of
  /// the values in the trailing window *before* it (the value itself is
  /// excluded). Nil when fewer than `minimumCount` trailing values exist or
  /// the trailing values are constant. Deviations from personal baseline
  /// carry the trigger signal better than absolute levels, and z-scoring
  /// removes slow seasonal drift.
  ///
  /// - Parameters:
  ///   - values: The time-ordered values.
  ///   - timestamps: The values' timestamps (same order and length).
  ///   - window: The trailing window.
  ///   - minimumCount: The minimum trailing values required.
  /// - Returns: A z-score (or nil) per input value.
  static func rollingZScores(values: [Double], timestamps: [Date], window: TimeInterval = 14.0 * 86400.0, minimumCount: Int = 5) -> [Double?] {
    guard values.count == timestamps.count else {
      return values.map({ _ in nil })
    }

    var zScores = [Double?]()
    var windowStart = 0

    for index in values.indices {
      // Advance the trailing window's left edge.
      while windowStart < index && timestamps[index].timeIntervalSince(timestamps[windowStart]) > window {
        windowStart += 1
      }

      let trailing = values[windowStart ..< index]
      guard trailing.count >= minimumCount else {
        zScores.append(nil)
        continue
      }

      let mean = trailing.reduce(0.0, +) / Double(trailing.count)
      let variance = trailing.reduce(0.0, { $0 + ($1 - mean) * ($1 - mean) }) / Double(trailing.count)
      let std = sqrt(variance)

      guard std > 0.0 else {
        zScores.append(nil)
        continue
      }

      // Winsorize: a near-constant trailing window makes tiny deviations
      // explode into extreme z-scores whose leverage dominates Pearson.
      let z = (values[index] - mean) / std
      zScores.append(min(max(z, -6.0), 6.0))
    }

    return zScores
  }

  /// First-order partial correlation between x and y controlling for z,
  /// via the closed form over the pairwise Pearson coefficients.
  ///
  /// - Parameters:
  ///   - x: The first array.
  ///   - y: The second array.
  ///   - z: The control array.
  /// - Returns: The partial correlation, or nil when undefined.
  static func partial(_ x: [Double], _ y: [Double], controlling z: [Double]) -> Double? {
    guard let rxy = pearson(x, y), let rxz = pearson(x, z), let ryz = pearson(y, z) else {
      return nil
    }

    let denominator = sqrt((1.0 - rxz * rxz) * (1.0 - ryz * ryz))
    guard denominator > 0.0 else {
      return nil
    }

    return (rxy - rxz * ryz) / denominator
  }

  /// Benjamini-Hochberg FDR-adjusted q-values for a family of p-values.
  ///
  /// - Parameter pValues: The p-values.
  /// - Returns: The q-values in the original order.
  static func benjaminiHochberg(_ pValues: [Double]) -> [Double] {
    let n = pValues.count
    guard n > 0 else {
      return []
    }

    let order = pValues.indices.sorted(by: { pValues[$0] < pValues[$1] })
    var qValues = [Double](repeating: 0.0, count: n)
    var minSoFar = 1.0

    for rank in stride(from: n - 1, through: 0, by: -1) {
      let index = order[rank]
      let value = min(minSoFar, pValues[index] * Double(n) / Double(rank + 1))
      minSoFar = value
      qValues[index] = value
    }

    return qValues
  }

}
