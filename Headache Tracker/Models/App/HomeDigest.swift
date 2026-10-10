//
//  HomeDigest.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import Foundation

/// The "what changed since you last looked" digest shown on the home screen —
/// a couple of short, caring lines derived by diffing the current forecast and
/// triggers against the last-seen snapshot. Pure and testable.
struct RiskDigest: Equatable {

  /// The minimum probability change (points) worth surfacing.
  static let minimumChange = 0.08

  /// The digest lines, most notable first (empty when nothing changed).
  let lines: [String]

  var isEmpty: Bool { lines.isEmpty }

  /// Builds the digest from current vs. last-seen state.
  ///
  /// - Parameters:
  ///   - current: The latest forecast.
  ///   - lastSeen: The forecast the last time the home was viewed.
  ///   - currentTriggers: The user's current confident trigger features.
  ///   - lastTriggers: The trigger features at last view.
  /// - Returns: The digest.
  static func make(current: RiskPrediction?, lastSeen: RiskPrediction?, currentTriggers: Set<CorrelationFeature>, lastTriggers: Set<CorrelationFeature>) -> RiskDigest {
    var lines = [String]()

    if let current = current, current.probability >= 0,
       let lastSeen = lastSeen, lastSeen.probability >= 0 {
      let delta = current.probability - lastSeen.probability
      if abs(delta) >= minimumChange {
        let percent = Int((abs(delta) * 100).rounded())
        lines.append(delta > 0
          ? "Risk is up \(percent)% since you last checked."
          : "Risk is down \(percent)% since you last checked.")
      }
    }

    let newTriggers = currentTriggers.subtracting(lastTriggers)
    for feature in newTriggers.sorted(by: { $0.title < $1.title }).prefix(2) {
      lines.append("New trigger linked to your headaches: \(feature.title).")
    }

    return RiskDigest(lines: lines)
  }
}

/// A celebratory model milestone (first model trained, accuracy improved).
/// Pure and testable; the caller persists the snapshot it compares against.
struct ModelMilestone: Equatable {

  /// The minimum accuracy gain (fraction) worth celebrating.
  static let minimumImprovement = 0.05

  /// The fewest resolved forecasts before prospective accuracy counts.
  static let minimumResolvedCount = 30

  /// A short, positive message.
  let message: String

  /// Evaluates whether a milestone was just crossed.
  ///
  /// - Parameters:
  ///   - hadModel: Whether a model existed at the last snapshot.
  ///   - hasModel: Whether a model exists now.
  ///   - previousAccuracy: The prospective accuracy at the last snapshot.
  ///   - currentAccuracy: The prospective accuracy now.
  /// - Returns: A milestone, or nil.
  static func evaluate(hadModel: Bool, hasModel: Bool, previousAccuracy: Double?, currentAccuracy: Double?) -> ModelMilestone? {
    if !hadModel && hasModel {
      return ModelMilestone(message: "Your personal model just turned on — forecasts are now tuned to you.")
    }
    if hasModel, let current = currentAccuracy, let previous = previousAccuracy,
       current - previous >= minimumImprovement {
      return ModelMilestone(message: "Your forecasts have been right \(Int((current * 100).rounded()))% of the time over the last few weeks — up from \(Int((previous * 100).rounded()))%.")
    }
    return nil
  }
}
