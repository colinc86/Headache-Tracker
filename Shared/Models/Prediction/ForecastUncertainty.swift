//
//  ForecastUncertainty.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import Foundation

/// A plausible range around a forecast probability, from the spread of the
/// bagged ensemble's calibrated outputs. Both bounds are calibrated
/// probabilities in 0…1, so the range reads like the point estimate: "on 100
/// days like today, somewhere between 44 and 66 bring a headache".
///
/// The members share the main model's Platt calibration, so the range carries
/// the trees' sampling variance but not the calibration's own uncertainty.
struct RiskInterval: Codable, Equatable {

  /// The lower bound.
  let lower: Double

  /// The upper bound.
  let upper: Double

  init(lower: Double, upper: Double) {
    self.lower = min(lower, upper)
    self.upper = max(lower, upper)
  }

  /// The range's width in probability.
  var width: Double {
    return upper - lower
  }

  /// The range as whole percents: "44–66%".
  var rangeText: String {
    return "\(RiskInterval.percent(lower))–\(RiskInterval.percent(upper))%"
  }

  /// The range for VoiceOver: "likely between 44 and 66 percent".
  var spokenText: String {
    return "likely between \(RiskInterval.percent(lower)) and \(RiskInterval.percent(upper)) percent"
  }

  /// Whether a probability falls inside the range.
  func contains(_ probability: Double) -> Bool {
    return probability >= lower && probability <= upper
  }

  private static func percent(_ probability: Double) -> Int {
    return Int((probability * 100.0).rounded())
  }

}

/// How much of the model's expected raw input was actually measured for a
/// forecast, versus filled from the training medians. Weather counts as one
/// signal; window statistics follow their raw metric and aren't counted
/// twice.
struct InputCoverage: Codable, Equatable {

  /// The expected signals that were measured.
  let presentSignals: Int

  /// The signals the model expects (enabled metrics with a training median,
  /// plus weather when the medians carry it).
  let expectedSignals: Int

  /// The signals filled from medians.
  var imputedSignals: Int {
    return max(expectedSignals - presentSignals, 0)
  }

  /// The measured fraction, 1 when nothing was expected.
  var fraction: Double {
    guard expectedSignals > 0 else {
      return 1.0
    }
    return min(max(Double(presentSignals) / Double(expectedSignals), 0.0), 1.0)
  }

  /// A short description: "9 of 11 signals".
  var summary: String {
    return "\(presentSignals) of \(expectedSignals) signals"
  }

}

/// A coarse grade of how much to lean on a forecast, from the range's width
/// and the input coverage. Deliberately not the Insights `Confidence`
/// vocabulary: that grades statistical evidence for a trigger; this grades
/// one day's forecast.
enum ForecastConfidence: String, Codable, CaseIterable {

  /// Narrow range, nearly every signal measured.
  case steady

  /// A wider range or a few estimated signals.
  case fair

  /// No range, a very wide one, or half the signals missing.
  case rough

  /// A title suitable for a badge.
  var title: String {
    return rawValue.capitalized
  }

  /// A one-line explanation.
  var caption: String {
    switch self {
    case .steady: return "The model has seen plenty of days like today."
    case .fair: return "Some of today's signals are estimated or the model is unsure."
    case .rough: return "Treat this as a rough guess: few comparable days or missing signals."
    }
  }

}

/// The headline accuracy shown beside the confidence grade: how often the
/// thresholded forecast matched what happened. Observed over the user's own
/// resolved forecasts once enough exist, else the training-time out-of-fold
/// accuracy (every row scored by a model that never saw its day).
struct ForecastAccuracy: Codable, Equatable {

  /// Where the number came from.
  enum Source: String, Codable {
    case observed
    case outOfFold
  }

  /// The accuracy in 0…1.
  let value: Double

  /// Where the number came from.
  let source: Source

  /// The resolved forecasts behind an observed value (0 when out-of-fold).
  let count: Int

  /// The fewest resolved forecasts before the observed record takes over.
  static let minimumObservedCount = 30

  /// "71% accurate".
  var text: String {
    return "\(Int((value * 100.0).rounded()))% accurate"
  }

  /// A spoken form: "71 percent accurate".
  var spokenText: String {
    return "\(Int((value * 100.0).rounded())) percent accurate"
  }

  /// One sentence on where the number came from.
  var sourceDescription: String {
    switch source {
    case .observed:
      return "Accuracy over your \(count) resolved forecasts."
    case .outOfFold:
      return "Accuracy from the training evaluation; it switches to your real forecasts once \(ForecastAccuracy.minimumObservedCount) have resolved."
    }
  }

  /// The headline accuracy.
  ///
  /// - Parameters:
  ///   - observedAccuracy: The accuracy over resolved forecasts, when any.
  ///   - observedCount: How many forecasts have resolved.
  ///   - outOfFold: The training-time out-of-fold accuracy, when any.
  /// - Returns: The headline, or nil when neither exists.
  static func headline(observedAccuracy: Double?, observedCount: Int, outOfFold: Double?) -> ForecastAccuracy? {
    if let observed = observedAccuracy, observedCount >= minimumObservedCount {
      return ForecastAccuracy(value: observed, source: .observed, count: observedCount)
    }
    if let outOfFold = outOfFold {
      return ForecastAccuracy(value: outOfFold, source: .outOfFold, count: 0)
    }
    return nil
  }

}

/// The pure math behind the per-forecast range and grade. Simulator-safe.
enum ForecastUncertainty {

  /// The fewest ensemble members a range is reported from.
  static let minimumMembers = 3

  /// The percentile the range spans on each side of the member spread.
  static let tailQuantile = 0.10

  /// The range width at or below which a well-covered forecast reads steady.
  static let steadyWidth = 0.15

  /// The range width above which a forecast reads rough.
  static let roughWidth = 0.30

  /// The coverage at or above which a forecast can read steady.
  static let steadyCoverage = 0.75

  /// The coverage below which a forecast reads rough.
  static let roughCoverage = 0.50

  /// The range spanned by the ensemble members around the point estimate:
  /// the 10th–90th percentile of the members, widened to include the point
  /// and clamped to 0…1.
  ///
  /// - Parameters:
  ///   - point: The published probability.
  ///   - members: The members' calibrated probabilities.
  /// - Returns: The range, or nil with too few members.
  static func interval(point: Double, members: [Double]) -> RiskInterval? {
    guard members.count >= minimumMembers else {
      return nil
    }

    let lower = ClassificationMetrics.percentile(members, tailQuantile)
    let upper = ClassificationMetrics.percentile(members, 1.0 - tailQuantile)
    guard lower.isFinite, upper.isFinite else {
      return nil
    }

    return RiskInterval(
      lower: min(max(min(lower, point), 0.0), 1.0),
      upper: min(max(max(upper, point), 0.0), 1.0))
  }

  /// Grades a forecast from its range and coverage.
  ///
  /// - Parameters:
  ///   - interval: The range, when an ensemble produced one.
  ///   - coverage: The input coverage, when known.
  /// - Returns: The grade.
  static func confidence(interval: RiskInterval?, coverage: InputCoverage?) -> ForecastConfidence {
    let fraction = coverage?.fraction ?? 1.0

    guard let interval = interval else {
      // Without a range the grade rests on coverage alone, and can never
      // read steady: the model's own spread is unknown.
      return fraction < roughCoverage ? .rough : .fair
    }

    // A hair of tolerance so a range of exactly 0.15 or 0.30 lands on the
    // intended side of the threshold despite floating-point subtraction.
    let epsilon = 1e-9
    if interval.width > roughWidth + epsilon || fraction < roughCoverage {
      return .rough
    }
    if interval.width <= steadyWidth + epsilon && fraction >= steadyCoverage {
      return .steady
    }
    return .fair
  }

}
