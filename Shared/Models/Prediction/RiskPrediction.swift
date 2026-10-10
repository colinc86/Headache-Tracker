//
//  RiskPrediction.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation

/// A side-effect-free score of one input on both horizons, for the what-if
/// explorer.
struct ScenarioScore: Equatable {

  /// The calibrated 24-hour probability, or -1 when no model is loaded.
  let probability24: Double

  /// The calibrated 12-hour probability, when the shorter-horizon
  /// classifier is trained.
  let probability12: Double?

  /// The plausible range around the 24-hour probability, when the caller
  /// asked for it and an ensemble is loaded.
  var interval24: RiskInterval? = nil

  /// Whether a model produced the score.
  var hasModel: Bool {
    return probability24 >= 0
  }

}

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

  /// A single signal's estimated contribution to this forecast, from swapping
  /// it to the user's baseline and re-running the model. `delta > 0` means the
  /// signal is raising risk; `< 0` means it's easing it. Contributions are
  /// independent "what if this were normal" estimates — they do NOT sum to the
  /// total probability.
  struct RiskContribution: Equatable, Codable, Identifiable {

    /// The correlated feature this contribution maps to, when it has one.
    let feature: CorrelationFeature?

    /// The ML feature/signal name.
    let mlFeatureName: String

    /// The change in calibrated probability attributable to this signal
    /// (positive raises risk, negative eases it).
    let delta: Double

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

  /// The calibrated probability of a headache within the shorter horizon
  /// (~12 hours), when the shorter-horizon classifier is trained. Optional so
  /// forecasts from models trained before it existed decode cleanly.
  var shortProbability: Double? = nil

  /// Per-signal contributions to this forecast, strongest first. Optional and
  /// device-only (computed at predict time, skipped in the widget), so older
  /// or widget-sourced blobs decode cleanly.
  var contributions: [RiskContribution]? = nil

  /// The plausible range around `probability`, from the bagged ensemble's
  /// spread. Optional so forecasts from models trained before the ensemble
  /// existed decode cleanly; nil when no ensemble is loaded.
  var interval: RiskInterval? = nil

  /// How much of the expected input was measured rather than imputed.
  /// Optional for the same reason.
  var coverage: InputCoverage? = nil

  /// The model's out-of-fold accuracy at training, carried so surfaces
  /// without the metrics sidecar (the widgets) can show a headline accuracy
  /// before enough forecasts have resolved. Optional for the same reason.
  var modelAccuracy: Double? = nil

  /// How much to lean on this forecast, from the range and the coverage.
  var confidence: ForecastConfidence {
    return ForecastUncertainty.confidence(interval: interval, coverage: coverage)
  }

  /// The prediction's tier.
  var tier: RiskTier {
    return RiskTier(probability: probability)
  }

  /// The shorter-horizon tier, when a shorter-horizon probability exists.
  var shortTier: RiskTier? {
    guard let shortProbability = shortProbability, shortProbability >= 0 else {
      return nil
    }
    return RiskTier(probability: shortProbability)
  }

  /// A one-line caption for the shorter-horizon forecast, or nil when there
  /// is no shorter-horizon probability.
  var shortCaption: String? {
    guard let shortProbability = shortProbability, shortProbability >= 0 else {
      return nil
    }
    return "\(Int((shortProbability * 100.0).rounded()))% chance within the next 12 hours"
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.probability == rhs.probability && lhs.shortProbability == rhs.shortProbability && lhs.topFactors == rhs.topFactors && lhs.contributions == rhs.contributions && lhs.interval == rhs.interval && lhs.coverage == rhs.coverage && lhs.modelAccuracy == rhs.modelAccuracy
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
      return "Since \(Formatters.formatTimeWithDay(since))"
    }
  }

}
