//
//  RiskPrediction.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation

/// A calibrated forecast of headache risk within the next 24 hours.
struct RiskPrediction: Equatable, Codable {

  /// A feature contributing to the current risk.
  struct RiskFactor: Equatable, Codable, Identifiable {

    /// The direction of the deviation driving the contribution.
    enum Direction: String, Codable {
      case elevated
      case reduced
    }

    /// The correlated feature, when the factor maps to one.
    let feature: CorrelationFeature?

    /// The ML feature name the factor came from.
    let mlFeatureName: String

    /// The deviation direction versus the user's baseline.
    let direction: Direction

    /// A human-readable description of the contribution.
    let contributionDescription: String

    var id: String {
      return mlFeatureName
    }
  }

  /// A coarse tier for presenting the probability.
  enum RiskTier: String, Codable {
    case low
    case elevated
    case high

    /// The probability at or above which risk reads as elevated.
    static let elevatedThreshold = 0.30

    /// The probability at or above which risk reads as high.
    static let highThreshold = 0.60

    /// The probability at or above which an evaluation counts the forecast
    /// as predicting a headache.
    static let evaluationPositiveThreshold = 0.50

    init(probability: Double) {
      if probability >= RiskTier.highThreshold {
        self = .high
      }
      else if probability >= RiskTier.elevatedThreshold {
        self = .elevated
      }
      else {
        self = .low
      }
    }

    /// A title suitable for the user interface.
    var title: String {
      switch self {
      case .low: return "Low Risk"
      case .elevated: return "Elevated Risk"
      case .high: return "High Risk"
      }
    }
  }

  /// An empty prediction, produced when no trained model is available.
  static let empty = RiskPrediction(
    input: .empty,
    probability: -1.0,
    topFactors: [],
    computedAt: Date(timeIntervalSince1970: 0))

  /// The model input that generated this prediction.
  var input: ModelInput

  /// The calibrated probability of a headache within the next 24 hours.
  var probability: Double

  /// The features the model most relied on, strongest first.
  var topFactors: [RiskFactor]

  /// When the prediction was computed.
  var computedAt: Date

  /// The prediction's tier.
  var tier: RiskTier {
    return RiskTier(probability: probability)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.probability == rhs.probability && lhs.topFactors == rhs.topFactors
  }

}

/// What the outlook surface should show: a forecast, or the logged state of
/// an active headache.
enum RiskOutlook {

  /// No headache is in progress; show the risk forecast.
  case risk(RiskPrediction)

  /// A headache is in progress.
  case activeHeadache(severity: Headache.Severity, since: Date?)

  /// Whether the outlook has no real forecast to show.
  var isEmpty: Bool {
    if case .risk(let prediction) = self {
      return prediction.probability < 0
    }
    return false
  }

  /// A title suitable for the user interface.
  var title: String {
    switch self {
    case .risk(let prediction):
      // An empty prediction must not read as a real "Low Risk" forecast.
      guard prediction.probability >= 0 else {
        return "No Forecast Yet"
      }
      return prediction.tier.title
    case .activeHeadache(let severity, _):
      return "\(severity.title) Headache"
    }
  }

  /// A caption suitable for the user interface, or nil.
  var caption: String? {
    switch self {
    case .risk(let prediction):
      guard prediction.probability >= 0 else {
        return nil
      }
      return "\(Int((prediction.probability * 100.0).rounded()))% chance of a headache in the next 24 hours"
    case .activeHeadache(_, let since):
      guard let since = since else {
        return nil
      }
      return "Since \(Formatters.formatTime(since))"
    }
  }

}
