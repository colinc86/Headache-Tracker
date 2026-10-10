//
//  RiskDriver.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Foundation

/// One thing moving today's forecast, for the Track tab's drivers strip and
/// the risk summary: the model's signed contribution for a signal, joined with
/// today's value and the user's usual one. Signals that deviate in the
/// direction of a confident trigger insight but carry no model contribution
/// are added after them. Pure.
struct RiskDriver: Identifiable, Equatable {

  /// The signal, when it maps to a correlation feature.
  let feature: CorrelationFeature?

  /// The display title.
  let title: String

  /// The SF Symbol.
  let systemImage: String

  /// Today's value, formatted.
  let todayText: String?

  /// The user's usual value, formatted.
  let usualText: String?

  /// The change in probability the signal accounts for, when the model
  /// attributed one.
  let delta: Double?

  /// Whether the signal is raising risk.
  let raising: Bool

  var id: String {
    return feature?.rawValue ?? title
  }

  /// The signed change in whole points: "+11", "−3".
  var deltaText: String? {
    guard let delta = delta else {
      return nil
    }
    let points = Int((delta * 100.0).rounded())
    return points < 0 ? "−\(abs(points))" : "+\(points)"
  }

  /// The most drivers shown.
  static let limit = 5

  /// Builds the drivers for a forecast.
  ///
  /// - Parameters:
  ///   - prediction: The forecast.
  ///   - report: The cached insights report, for baselines and insights.
  /// - Returns: The drivers, strongest first.
  static func make(prediction: RiskPrediction, report: InsightsReport?) -> [RiskDriver] {
    guard prediction.probability >= 0 else {
      return []
    }

    let values = prediction.input.correlationValues()
    let baselines = report?.baselines ?? [:]
    var drivers = [RiskDriver]()

    for contribution in (prediction.contributions ?? []).sorted(by: { abs($0.delta) > abs($1.delta) }) {
      let feature = contribution.feature
      drivers.append(RiskDriver(
        feature: feature,
        title: feature?.title ?? contribution.mlFeatureName,
        systemImage: feature?.systemImage ?? "waveform.path.ecg",
        todayText: feature.flatMap({ feature in values[feature].map(feature.format) }),
        usualText: feature.flatMap({ feature in baselines[feature].map({ feature.format($0.mean) }) }),
        delta: contribution.delta,
        raising: contribution.delta > 0))
    }

    // Deviations behind confident insights that the model didn't attribute.
    let present = Set(drivers.compactMap({ $0.feature }))
    for insight in (report?.insights ?? []) where insight.target == .occurrence && insight.explainedBy == nil && insight.confidence != .suggestive {
      guard !present.contains(insight.feature),
            !drivers.contains(where: { $0.feature == insight.feature }),
            let value = values[insight.feature],
            let baseline = baselines[insight.feature],
            baseline.std > 0 else {
        continue
      }
      let z = (value - baseline.mean) / baseline.std
      guard abs(z) >= RiskBriefBuilder.minimumDeviation, (z > 0) == insight.higherIsAssociated else {
        continue
      }
      drivers.append(RiskDriver(
        feature: insight.feature,
        title: insight.feature.title,
        systemImage: insight.feature.systemImage,
        todayText: insight.feature.format(value),
        usualText: insight.feature.format(baseline.mean),
        delta: nil,
        raising: true))
    }

    return Array(drivers.prefix(limit))
  }

}
