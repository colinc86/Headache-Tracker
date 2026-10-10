//
//  SummaryFacts.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import CryptoKit
import Foundation

/// The grounded fact sheet behind the Track tab's risk summary. Everything is
/// already formatted for people, so the writer (template or language model)
/// only rewrites; it never sees raw data or does arithmetic. Probabilities are
/// whole percents, so tiny changes don't trigger a rewrite.
struct RiskFacts: Codable, Hashable {

  /// One signal moving the forecast.
  struct Driver: Codable, Hashable {
    let signal: String
    let today: String?
    let usual: String?
    let points: Int?
    let raising: Bool
  }

  /// The 24-hour chance, in whole percent.
  let percent: Int

  /// "low", "elevated", or "high".
  let tier: String

  /// The plausible range, when the forecast carries one: "33–52%".
  let likelyRange: String?

  /// "rising", "falling", or "steady", when there's enough history.
  let trend: String?

  /// When the risk concentrates: "Mostly in the next 12 hours".
  let timing: String?

  /// The signals moving the forecast, strongest first.
  let drivers: [Driver]

  /// Signals that weren't measured and were estimated.
  let estimatedSignals: Int

  /// Builds the facts for a forecast.
  ///
  /// - Parameters:
  ///   - prediction: The forecast.
  ///   - drivers: The forecast's drivers.
  ///   - history: The logged forecasts over the last two days.
  /// - Returns: The facts, or nil without a forecast.
  static func make(prediction: RiskPrediction, drivers: [RiskDriver], history: [HeadacheManager.RiskHistoryPoint]) -> RiskFacts? {
    guard prediction.probability >= 0 else {
      return nil
    }

    let trajectory = RiskSnapshot.trajectory(probability: prediction.probability, computedAt: prediction.computedAt, history: history)
    let peak = RiskSnapshot.peakWindow(probability24: prediction.probability, probability12: prediction.shortProbability.flatMap({ $0 >= 0 ? $0 : nil }))
    let timing: String?
    switch peak {
    case .frontLoaded: timing = "Mostly in the next 12 hours"
    case .building: timing = "Building toward tomorrow"
    case .spread, .none: timing = nil
    }

    return RiskFacts(
      percent: Int((prediction.probability * 100.0).rounded()),
      tier: prediction.tier.rawValue,
      likelyRange: prediction.interval?.rangeText,
      trend: trajectory.map({ "\($0)" }),
      timing: timing,
      drivers: drivers.prefix(3).map { driver in
        Driver(
          signal: driver.title,
          today: driver.todayText,
          usual: driver.usualText,
          points: driver.delta.map({ Int((abs($0) * 100.0).rounded()) }),
          raising: driver.raising)
      },
      estimatedSignals: prediction.coverage?.imputedSignals ?? 0)
  }

  /// Every string a summary may draw numbers from.
  var groundingStrings: [String] {
    var strings = ["\(percent)%", "\(percent)", likelyRange, timing].compactMap({ $0 })
    for driver in drivers {
      strings += [driver.today, driver.usual, driver.points.map({ "\($0)" })].compactMap({ $0 })
    }
    return strings
  }

  /// The signal names a summary may mention.
  var signalNames: [String] {
    return drivers.map({ $0.signal })
  }

}

/// The grounded fact sheet behind the Profile tab's portrait.
struct ProfileFacts: Codable, Hashable {

  /// One confident trigger pattern.
  struct Pattern: Codable, Hashable {
    /// The pattern's key (the correlation feature's raw value).
    let id: String
    let signal: String
    let pattern: String
    let strength: String
    let leadHours: Int?
    let mayBeExplainedBy: String?
  }

  let windowDays: Int
  let headaches: Int
  let perMonth: String
  let trend: String
  let usualStart: String?
  let busiestDay: String?
  let typicalLength: String?
  let usualPeak: String?
  let longestFreeStretchDays: Int
  let patterns: [Pattern]
  let leadingAreas: [String]
  let mostHelpfulMedication: String?
  let forecastAccuracy: String?

  /// Builds the facts.
  ///
  /// - Parameters:
  ///   - analytics: The headache profile.
  ///   - report: The cached insights report.
  ///   - medications: Medication use and ratings over the window.
  ///   - accuracy: The forecast's headline accuracy.
  /// - Returns: The facts.
  static func make(analytics: ProfileAnalytics, report: InsightsReport?, medications: [ClinicianReportData.MedicationSummary], accuracy: ForecastAccuracy?) -> ProfileFacts {
    let confident = (report?.insights ?? []).filter({ $0.target == .occurrence && $0.confidence != .suggestive })
    let helpful = medications
      .filter({ $0.ratedCount > 0 })
      .max(by: { (Double($0.helpfulCount) / Double($0.ratedCount), $0.ratedCount) < (Double($1.helpfulCount) / Double($1.ratedCount), $1.ratedCount) })

    return ProfileFacts(
      windowDays: analytics.windowDays,
      headaches: analytics.headacheCount,
      perMonth: String(format: "%.1f", analytics.ratePerMonth),
      trend: analytics.direction.rawValue,
      usualStart: analytics.typicalOnsetText,
      busiestDay: analytics.peakWeekdayText(),
      typicalLength: analytics.medianDuration.map(Formatters.formatInterval),
      usualPeak: analytics.commonPeak.map({ $0.title.lowercased() }),
      longestFreeStretchDays: analytics.longestFreeStreak,
      patterns: confident.prefix(4).map { insight in
        Pattern(
          id: insight.feature.rawValue,
          signal: insight.feature.title,
          pattern: insight.directionDescription,
          strength: insight.strengthLabel,
          leadHours: insight.bestLagHours,
          mayBeExplainedBy: insight.explainedBy?.title)
      },
      leadingAreas: (report?.domainProfile ?? []).prefix(3).map({ $0.domain.title }),
      mostHelpfulMedication: helpful.flatMap({ $0.helpfulCount > 0 ? "\($0.name), helped \($0.helpfulCount) of \($0.ratedCount) times" : nil }),
      forecastAccuracy: accuracy?.text)
  }

  /// Every string a portrait may draw numbers from.
  var groundingStrings: [String] {
    var strings = ["\(windowDays)", "\(headaches)", perMonth, "\(longestFreeStretchDays)", usualStart, typicalLength, mostHelpfulMedication, forecastAccuracy].compactMap({ $0 })
    strings += patterns.compactMap({ $0.leadHours.map({ "\($0)" }) })
    return strings
  }

  /// The signal and area names a portrait may mention.
  var signalNames: [String] {
    return patterns.flatMap({ [$0.signal, $0.mayBeExplainedBy].compactMap({ $0 }) }) + leadingAreas
  }

}

extension Encodable {

  /// A stable cache key: SHA-256 of the sorted-key JSON encoding.
  var summaryCacheKey: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(self)) ?? Data()
    return SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined()
  }

  /// The compact JSON handed to the language model.
  var summaryPromptJSON: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(self)).flatMap({ String(data: $0, encoding: .utf8) }) ?? "{}"
  }

}
