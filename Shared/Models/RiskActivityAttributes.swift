//
//  RiskActivityAttributes.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import ActivityKit
import Foundation

/// The Live Activity describing the current headache-risk forecast during a
/// high-risk window — a glanceable gauge on the lock screen / Dynamic Island.
struct RiskActivityAttributes: ActivityAttributes {

  /// The mutable state: the latest forecast.
  struct ContentState: Codable, Hashable {

    /// The calibrated probability of a headache within the next 24 hours.
    var probability: Double

    /// The shorter-horizon (~12h) probability, when available.
    var shortProbability: Double?

    /// When the forecast was computed.
    var computedAt: Date

    /// The forecast's coarse tier.
    var tier: RiskPrediction.RiskTier {
      return RiskPrediction.RiskTier(probability: probability)
    }
  }

  /// When the high-risk window's activity began.
  let startedAt: Date

}
