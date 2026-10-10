//
//  PersonalizationSelection.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// The candidate-and-promote personalization decision, persisted beside the
/// model as `personalization.json`.
///
/// The correlation engine proposes the user's own confident onset features;
/// training builds a second model that carries extended temporal-context
/// columns for those features (see `TemporalContextInput`), evaluates both
/// with the same rolling-origin folds, and ships the personalized one only
/// when it wins. Base features are never removed, and the candidates are
/// chosen from each fold's training prefix only, so the comparison isn't
/// contaminated by the rows it is scored on. Pure; simulator-safe.
struct PersonalizationSelection: Codable, Equatable {

  /// The most features personalized at once.
  static let maximumCandidates = 5

  /// The FDR-adjusted q-value a finding needs to be a candidate.
  static let qValueThreshold = 0.15

  /// The AUC gain the personalized model must show to be promoted.
  static let promotionMargin = 0.02

  /// The Brier score worsening the personalized model may not exceed.
  static let brierTolerance = 0.005

  /// The quantile of the paired-bootstrap AUC difference that must stay at
  /// or above zero. A 95% lower bound never clears zero at ~5 episodes, so
  /// the rule would be dead; a one-sided 80% criterion plus the margin and
  /// the Brier guard keeps false promotions rare while staying reachable.
  static let promotionQuantile = 0.20

  /// No personalization.
  static let empty = PersonalizationSelection(features: [], promoted: false, baseAUC: nil, personalizedAUC: nil, deltaLowerQuantile: nil)

  /// The candidate features, strongest first.
  let features: [CorrelationFeature]

  /// Whether the personalized model was promoted (shipped).
  let promoted: Bool

  /// The base model's rolling-origin AUC.
  let baseAUC: Double?

  /// The personalized model's rolling-origin AUC.
  let personalizedAUC: Double?

  /// The `promotionQuantile` of the paired-bootstrap AUC difference.
  let deltaLowerQuantile: Double?

  /// The features whose extended columns the shipped model carries.
  var activeFeatures: Set<CorrelationFeature> {
    return promoted ? Set(features) : []
  }

  /// A one-line status for the debug screen.
  var statusDescription: String {
    guard let baseAUC = baseAUC, let personalizedAUC = personalizedAUC else {
      return features.isEmpty ? "No candidates" : "Skipped: too few positives to compare"
    }
    let names = features.map({ $0.title }).joined(separator: ", ")
    if promoted {
      return String(format: "Promoted %+.2f AUC: %@", personalizedAUC - baseAUC, names)
    }
    return String(format: "Not promoted (%.2f vs. %.2f): %@", personalizedAUC, baseAUC, names)
  }

  /// The candidate features from a report computed on the training prefix
  /// only: confident, non-confounded onset associations for features that
  /// feed a modelled column, strongest first and capped.
  ///
  /// - Parameters:
  ///   - report: The insights report over the training prefix.
  ///   - modelled: The features with a window-context column.
  /// - Returns: The candidates.
  static func candidates(from report: InsightsReport, modelled: Set<CorrelationFeature>) -> [CorrelationFeature] {
    let eligible = report.insights.filter { insight in
      insight.target == .occurrence
        && insight.qValue < qValueThreshold
        && insight.explainedBy == nil
        && modelled.contains(insight.feature)
    }

    var seen = Set<CorrelationFeature>()
    var ordered = [CorrelationFeature]()
    for insight in eligible.sorted(by: { abs($0.coefficient) > abs($1.coefficient) }) where !seen.contains(insight.feature) {
      seen.insert(insight.feature)
      ordered.append(insight.feature)
    }
    return Array(ordered.prefix(maximumCandidates))
  }

  /// The features that have a window-context column (and so can be
  /// personalized), given the metrics with such columns.
  static func modelledFeatures() -> Set<CorrelationFeature> {
    var features = Set(HealthKitData.windowMetrics.compactMap({ CorrelationFeature(healthKitData: $0) }))
    for field in WeatherField.windowFields {
      features.insert(field.correlationFeature)
    }
    return features
  }

  /// Decides whether to promote the personalized model.
  ///
  /// - Parameters:
  ///   - features: The candidate features the personalized model carried.
  ///   - base: The base model's rolling-origin result.
  ///   - personalized: The personalized model's rolling-origin result.
  ///   - deltaSamples: The paired-bootstrap samples of (personalized − base)
  ///     AUC on the same cluster resamples.
  ///   - previous: The previous decision, for hysteresis.
  /// - Returns: The decision.
  static func decide(
    features: [CorrelationFeature],
    base: RollingOriginResult,
    personalized: RollingOriginResult,
    deltaSamples: [Double],
    previous: PersonalizationSelection?
  ) -> PersonalizationSelection {
    guard !features.isEmpty, base.isUsable, personalized.isUsable,
          let baseAUC = base.auc, let personalizedAUC = personalized.auc else {
      return PersonalizationSelection(features: features, promoted: false, baseAUC: base.auc, personalizedAUC: personalized.auc, deltaLowerQuantile: nil)
    }

    let delta = personalizedAUC - baseAUC
    let lowerQuantile = deltaSamples.isEmpty ? nil : ClassificationMetrics.percentile(deltaSamples, promotionQuantile)
    let brierOK: Bool
    if let baseBrier = base.brier, let personalizedBrier = personalized.brier {
      brierOK = personalizedBrier <= baseBrier + brierTolerance
    }
    else {
      brierOK = true
    }

    var promoted = delta >= promotionMargin && brierOK && (lowerQuantile ?? -1.0) >= 0.0

    // Hysteresis: an already-promoted identical set stays promoted unless it
    // now scores below the base, so nightly retrains don't flap on noise.
    if !promoted, let previous = previous, previous.promoted, previous.features == features, delta >= 0.0, brierOK {
      promoted = true
    }

    return PersonalizationSelection(features: features, promoted: promoted, baseAUC: baseAUC, personalizedAUC: personalizedAUC, deltaLowerQuantile: lowerQuantile)
  }

}
