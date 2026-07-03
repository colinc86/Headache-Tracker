//
//  Calibration.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation

/// Platt scaling: maps a classifier's raw scores to calibrated
/// probabilities via `sigmoid(a * logit(score) + b)`, fit on a held-out
/// validation slice. Two parameters resist overfitting on the small
/// validation slices this app produces, unlike isotonic regression.
struct PlattCalibration: Codable, Equatable {

  /// The identity calibration (raw scores pass through unchanged).
  static let identity = PlattCalibration(a: 1.0, b: 0.0)

  /// The logit scale parameter.
  let a: Double

  /// The logit offset parameter.
  let b: Double

  // MARK: Static methods

  /// Fits a calibration on validation scores and outcomes using gradient
  /// descent on log-loss with Platt's label smoothing.
  ///
  /// Returns nil when the slice is degenerate (fewer than 5 positives or
  /// 5 negatives) — callers should fall back to `identity` and mark the
  /// model uncalibrated.
  ///
  /// - Parameters:
  ///   - scores: The raw predicted probabilities.
  ///   - outcomes: The actual outcomes.
  /// - Returns: The fitted calibration, or nil for a degenerate slice.
  static func fit(scores: [Double], outcomes: [Bool]) -> PlattCalibration? {
    guard scores.count == outcomes.count else {
      return nil
    }

    let positiveCount = outcomes.lazy.filter({ $0 }).count
    let negativeCount = outcomes.count - positiveCount
    guard positiveCount >= 5 && negativeCount >= 5 else {
      return nil
    }

    // Platt's label smoothing keeps the fit from saturating.
    let positiveTarget = (Double(positiveCount) + 1.0) / (Double(positiveCount) + 2.0)
    let negativeTarget = 1.0 / (Double(negativeCount) + 2.0)

    let logits = scores.map(logit)
    let targets = outcomes.map({ $0 ? positiveTarget : negativeTarget })

    var a = 1.0
    var b = 0.0
    let learningRate = 0.01
    let count = Double(scores.count)

    for _ in 0 ..< 500 {
      var gradientA = 0.0
      var gradientB = 0.0

      for (logitValue, target) in zip(logits, targets) {
        let predicted = sigmoid(a * logitValue + b)
        let error = predicted - target
        gradientA += error * logitValue
        gradientB += error
      }

      a -= learningRate * gradientA / count
      b -= learningRate * gradientB / count
    }

    return PlattCalibration(a: a, b: b)
  }

  /// The Brier score (mean squared error of probabilities): lower is
  /// better; 0.25 is the score of always predicting 50%.
  ///
  /// - Parameters:
  ///   - probabilities: The predicted probabilities.
  ///   - outcomes: The actual outcomes.
  /// - Returns: The Brier score, or nil for empty input.
  static func brier(probabilities: [Double], outcomes: [Bool]) -> Double? {
    guard !probabilities.isEmpty, probabilities.count == outcomes.count else {
      return nil
    }

    let total = zip(probabilities, outcomes).reduce(0.0) { sum, pair in
      let outcome = pair.1 ? 1.0 : 0.0
      return sum + (pair.0 - outcome) * (pair.0 - outcome)
    }
    return total / Double(probabilities.count)
  }

  /// A calibration bucket: how often outcomes actually happened among
  /// predictions in a probability range.
  struct Bucket: Codable, Equatable {

    /// The bucket's lower probability bound.
    let lowerBound: Double

    /// The mean predicted probability in the bucket.
    let meanPredicted: Double

    /// The observed positive rate in the bucket.
    let observedRate: Double

    /// The number of predictions in the bucket.
    let count: Int
  }

  /// Buckets predictions into equal-width probability ranges.
  ///
  /// - Parameters:
  ///   - probabilities: The predicted probabilities.
  ///   - outcomes: The actual outcomes.
  ///   - count: The number of buckets.
  /// - Returns: The non-empty buckets.
  static func buckets(probabilities: [Double], outcomes: [Bool], count: Int = 5) -> [Bucket] {
    guard count > 0, !probabilities.isEmpty, probabilities.count == outcomes.count else {
      return []
    }

    let width = 1.0 / Double(count)
    var buckets = [Bucket]()

    for index in 0 ..< count {
      let lower = Double(index) * width
      let upper = index == count - 1 ? 1.0.nextUp : lower + width

      var predicted = [Double]()
      var positives = 0
      for (probability, outcome) in zip(probabilities, outcomes) where probability >= lower && probability < upper {
        predicted.append(probability)
        if outcome {
          positives += 1
        }
      }

      guard !predicted.isEmpty else {
        continue
      }

      buckets.append(Bucket(
        lowerBound: lower,
        meanPredicted: predicted.reduce(0.0, +) / Double(predicted.count),
        observedRate: Double(positives) / Double(predicted.count),
        count: predicted.count))
    }

    return buckets
  }

  // MARK: Public methods

  /// Applies the calibration to a raw score.
  ///
  /// - Parameter score: The raw predicted probability.
  /// - Returns: The calibrated probability.
  func apply(_ score: Double) -> Double {
    return PlattCalibration.sigmoid(a * PlattCalibration.logit(score) + b)
  }

  // MARK: Private methods

  private static func sigmoid(_ x: Double) -> Double {
    return 1.0 / (1.0 + exp(-x))
  }

  private static func logit(_ p: Double) -> Double {
    // Clamp away from 0/1 so the transform stays finite.
    let clamped = min(max(p, 1e-6), 1.0 - 1e-6)
    return log(clamped / (1.0 - clamped))
  }

}
