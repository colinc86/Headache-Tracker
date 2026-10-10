//
//  ProspectiveAccuracy.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// A resolved forecast: what the model said at the time and what happened.
struct EvaluationPoint: Identifiable, Equatable {

  /// When the forecast was made.
  let date: Date

  /// The calibrated probability the model gave.
  let probability: Double

  /// Whether an onset followed within the horizon.
  let outcome: Bool

  var id: Date {
    return date
  }

  /// Whether the thresholded forecast matched the outcome.
  var isCorrect: Bool {
    return (probability >= RiskPrediction.RiskTier.evaluationPositiveThreshold) == outcome
  }

}

/// Descriptive statistics over resolved forecasts — the model's *prospective*
/// record, as opposed to the rolling-origin evaluation computed at training
/// time. Forecasts are recorded hourly and are autocorrelated, so these are
/// descriptions, not inference. Pure; simulator-safe.
enum ProspectiveAccuracy {

  /// Accuracy over a trailing window ending at a date.
  struct WindowPoint: Identifiable, Equatable {
    let date: Date
    let accuracy: Double
    let brier: Double?
    let count: Int

    var id: Date {
      return date
    }
  }

  /// A summary of a set of points.
  struct Summary: Equatable {
    let accuracy: Double?
    let brier: Double?
    let auc: Double?
    let baseRateAccuracy: Double?
    let count: Int
  }

  /// The minimum points per window before a window point is emitted.
  static let minimumWindowCount = 5

  /// Trailing-window accuracy sampled at a fixed step.
  ///
  /// - Parameters:
  ///   - points: The resolved forecasts.
  ///   - window: The trailing window length.
  ///   - step: The spacing between window ends.
  /// - Returns: One point per window end with at least `minimumWindowCount`
  ///   forecasts, oldest first.
  static func rollingWindows(_ points: [EvaluationPoint], window: TimeInterval = 14.0 * 86400.0, step: TimeInterval = 86400.0) -> [WindowPoint] {
    guard let first = points.map({ $0.date }).min(), let last = points.map({ $0.date }).max(), step > 0 else {
      return []
    }

    let sorted = points.sorted(by: { $0.date < $1.date })
    var result = [WindowPoint]()
    var end = first.addingTimeInterval(window)
    while end <= last.addingTimeInterval(step) {
      let start = end.addingTimeInterval(-window)
      let inWindow = sorted.filter({ $0.date > start && $0.date <= end })
      if inWindow.count >= minimumWindowCount {
        let correct = inWindow.lazy.filter({ $0.isCorrect }).count
        result.append(WindowPoint(
          date: end,
          accuracy: Double(correct) / Double(inWindow.count),
          brier: PlattCalibration.brier(probabilities: inWindow.map({ $0.probability }), outcomes: inWindow.map({ $0.outcome })),
          count: inWindow.count))
      }
      end = end.addingTimeInterval(step)
    }
    return result
  }

  /// A summary of the points.
  ///
  /// - Parameter points: The resolved forecasts.
  /// - Returns: The summary (all-nil metrics when empty).
  static func summary(_ points: [EvaluationPoint]) -> Summary {
    guard !points.isEmpty else {
      return Summary(accuracy: nil, brier: nil, auc: nil, baseRateAccuracy: nil, count: 0)
    }

    let probabilities = points.map({ $0.probability })
    let outcomes = points.map({ $0.outcome })
    let positives = outcomes.lazy.filter({ $0 }).count
    let correct = points.lazy.filter({ $0.isCorrect }).count

    // What always forecasting the majority class would have scored.
    let majority = max(positives, points.count - positives)

    return Summary(
      accuracy: Double(correct) / Double(points.count),
      brier: PlattCalibration.brier(probabilities: probabilities, outcomes: outcomes),
      auc: ClassificationMetrics.auc(scores: probabilities, outcomes: outcomes),
      baseRateAccuracy: Double(majority) / Double(points.count),
      count: points.count)
  }

}
