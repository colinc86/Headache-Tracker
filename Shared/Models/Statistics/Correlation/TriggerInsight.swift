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

}

/// A full insights computation result.
struct InsightsReport: Codable {

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

}
