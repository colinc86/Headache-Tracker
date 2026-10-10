//
//  TriggerInsight.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Foundation

/// The result of correlating one feature against headaches.
struct TriggerInsight: Codable, Identifiable {

  /// What the feature was correlated against.
  enum Target: String, Codable {
    case occurrence
    case severity

    /// A title suitable for the user interface.
    var title: String {
      switch self {
      case .occurrence: return "Headache Onset"
      case .severity: return "Severity"
      }
    }
  }

  /// The confidence tier derived from the FDR-adjusted q-value.
  enum Confidence: String, Codable, Comparable {
    case strong
    case moderate
    case suggestive

    init(qValue: Double) {
      if qValue < 0.05 {
        self = .strong
      }
      else if qValue < 0.15 {
        self = .moderate
      }
      else {
        self = .suggestive
      }
    }

    /// A title suitable for the user interface.
    var title: String {
      return rawValue.capitalized
    }

    private var sortRank: Int {
      switch self {
      case .strong: return 0
      case .moderate: return 1
      case .suggestive: return 2
      }
    }

    static func < (lhs: Confidence, rhs: Confidence) -> Bool {
      return lhs.sortRank < rhs.sortRank
    }
  }

  /// The correlated feature.
  let feature: CorrelationFeature

  /// What the feature was correlated against.
  let target: Target

  /// The correlation coefficient: point-biserial for occurrence, Spearman
  /// for severity.
  let coefficient: Double

  /// The FDR-adjusted significance of the coefficient.
  let qValue: Double

  /// The lead time (hours before onset) with the strongest association.
  /// Nil for the severity target.
  let bestLagHours: Int?

  /// The coefficient per tested lag, for the lag profile chart.
  let lagProfile: [Int: Double]

  /// The number of feature-target pairs in the test.
  let sampleCount: Int

  /// The number of positive samples (pre-onset windows, or in-headache rows
  /// for the severity target).
  let eventCount: Int

  /// The feature's mean over positive samples.
  let positiveMean: Double

  /// The feature's mean over baseline samples.
  let baselineMean: Double

  /// Whether the coefficient was computed over personal-baseline z-scores
  /// rather than raw values. Optional so old cached reports decode.
  let usesBaselineRelative: Bool?

  /// A strongly co-correlated feature that largely explains this finding,
  /// when the confounder pass detected one. Optional for old reports.
  let explainedBy: CorrelationFeature?

  /// The partial correlation controlling for `explainedBy`. Optional for
  /// old reports.
  let partialCoefficient: Double?

  var id: String {
    return "\(feature.rawValue)-\(target.rawValue)"
  }

  /// The confidence tier.
  var confidence: Confidence {
    return Confidence(qValue: qValue)
  }

  /// Whether higher feature values associate with more headaches.
  var higherIsAssociated: Bool {
    return coefficient > 0.0
  }

  /// A one-line description of the association's direction.
  var directionDescription: String {
    let direction = higherIsAssociated ? "Higher" : "Lower"
    switch target {
    case .occurrence:
      return "\(direction) \(feature.title.lowercased()) before headaches"
    case .severity:
      return "\(direction) \(feature.title.lowercased()) with worse headaches"
    }
  }

  /// A word describing the association's magnitude, from `|coefficient|`.
  var strengthLabel: String {
    switch abs(coefficient) {
    case 0.5...: return "strong"
    case 0.3 ..< 0.5: return "moderate"
    default: return "weak"
    }
  }

}

/// A feature's recent personal baseline.
struct FeatureBaseline: Codable, Equatable {

  /// The trailing mean.
  let mean: Double

  /// The trailing standard deviation.
  let std: Double

  /// The number of values in the window.
  let count: Int

}

/// A full insights computation result.
struct InsightsReport: Codable {

  /// The current report schema version; cached reports with a different
  /// (or missing) version are recomputed.
  ///
  /// 3: dropped the manual daily check-in — the six `exposure*` features no
  /// longer exist, so prior reports must recompute without them.
  static let currentSchemaVersion = 3

  /// A feature that couldn't be tested for lack of data.
  struct InsufficientFeature: Codable, Identifiable {

    /// The feature.
    let feature: CorrelationFeature

    /// The number of usable samples observed.
    let sampleCount: Int

    var id: String {
      return feature.rawValue
    }
  }

  /// When the report was computed.
  let generatedAt: Date

  /// The number of training data rows the report was computed from.
  let rowCount: Int

  /// Features with enough data, ranked strongest first.
  let insights: [TriggerInsight]

  /// Features skipped for lack of data.
  let insufficient: [InsufficientFeature]

  /// Per-feature trailing-14-day baselines at report time, for the morning
  /// brief's "vs. your usual" comparisons. Optional for old reports.
  let baselines: [CorrelationFeature: FeatureBaseline]?

  /// The schema version the report was computed with. Optional for old
  /// reports (which read as stale).
  let schemaVersion: Int?

  /// The set of enabled predictors the report was computed with. Optional for
  /// old reports (which read as stale and recompute once).
  let enabledFingerprint: String?

  /// A deterministic fingerprint for a set of enabled features.
  ///
  /// Sorted raw values rather than `hashValue` — Swift seeds `Hasher`
  /// randomly per process, so a hash would differ on every launch and keep
  /// the cache permanently stale.
  ///
  /// - Parameter features: The enabled features.
  /// - Returns: The fingerprint.
  static func fingerprint(for features: Set<CorrelationFeature>) -> String {
    return features.map({ $0.rawValue }).sorted().joined(separator: ",")
  }

}

extension InsightsReport {

  /// A domain in the user's trigger profile: the signal group, its strongest
  /// association strength, and its confident insights (strongest first).
  struct DomainProfile: Identifiable {
    let domain: SignalDomain
    let strength: Double
    let insights: [TriggerInsight]

    var id: String { domain.rawValue }
  }

  /// The user's trigger profile — "are you a sleep person or a weather
  /// person": confident, non-confounded onset associations grouped by domain,
  /// domains ranked by their strongest association. Empty until enough data.
  var domainProfile: [DomainProfile] {
    let confident = insights.filter {
      $0.target == .occurrence && $0.confidence != .suggestive && $0.explainedBy == nil
    }

    let grouped = Dictionary(grouping: confident, by: { $0.feature.domain })
    return grouped.map { domain, list -> DomainProfile in
      let ranked = list.sorted { abs($0.coefficient) > abs($1.coefficient) }
      return DomainProfile(domain: domain, strength: ranked.first.map { abs($0.coefficient) } ?? 0.0, insights: ranked)
    }
    .sorted { $0.strength > $1.strength }
  }

}
