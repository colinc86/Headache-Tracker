//
//  SummaryWriter.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Foundation

/// A short piece of summary prose.
struct SummaryText: Codable, Equatable {

  /// The prose.
  let text: String

  /// Whether a language model wrote it (otherwise a template did).
  let isGenerated: Bool

}

/// The Profile tab's written portrait.
struct ProfilePortrait: Codable, Equatable {

  /// A few words naming what leads the user's headaches.
  let headline: String

  /// Two or three sentences.
  let body: String

  /// One plain-language line per trigger pattern, keyed by the correlation
  /// feature's raw value.
  let insightLines: [String: String]

  /// Whether a language model wrote it.
  let isGenerated: Bool

}

/// Writes summaries that may take time (a language model).
protocol GenerativeSummaryWriter {

  /// The risk summary for the Track tab.
  func riskSummary(_ facts: RiskFacts) async -> SummaryText

  /// The portrait for the Profile tab.
  func portrait(_ facts: ProfileFacts) async -> ProfilePortrait

}

/// The deterministic summaries: what shows on the simulator, on devices
/// without Apple Intelligence, while the model writes, and whenever its
/// output fails validation. Pure.
struct TemplateSummaryWriter {

  // MARK: Risk

  /// The risk summary: what's moving the forecast, then when it concentrates.
  func riskSummary(_ facts: RiskFacts) -> SummaryText {
    let raising = facts.drivers.filter({ $0.raising })
    let easing = facts.drivers.filter({ !$0.raising })

    var sentences = [String]()
    if !raising.isEmpty {
      // Only the strongest driver carries its values; a second is named.
      let phrases = raising.prefix(2).enumerated().map({ $0.offset == 0 ? phrase(for: $0.element) : $0.element.signal.lowercased() })
      sentences.append("\(TemplateSummaryWriter.joined(phrases)) \(phrases.count == 1 ? "is" : "are") pushing your risk up.")
    }
    else if let first = easing.first {
      sentences.append("\(phrase(for: first)) is working in your favor.")
    }
    else {
      switch facts.tier {
      case "high": sentences.append("Your signals line up with days that led to headaches.")
      case "elevated": sentences.append("Your risk is above your usual, without one standout signal.")
      default: sentences.append("Nothing in your signals stands out today.")
      }
    }

    if let timing = facts.timing {
      sentences.append(timing + (facts.trend == "rising" ? ", and climbing." : "."))
    }
    else if facts.trend == "rising" {
      sentences.append("It has been climbing over the last few hours.")
    }
    else if facts.trend == "falling" {
      sentences.append("It has been easing over the last few hours.")
    }

    return SummaryText(text: sentences.map(TemplateSummaryWriter.capitalized).joined(separator: " "), isGenerated: false)
  }

  /// A driver as a phrase: "sleep duration at 5h 12m (usual 7h 6m)".
  private func phrase(for driver: RiskFacts.Driver) -> String {
    let name = driver.signal.lowercased()
    if let today = driver.today, let usual = driver.usual {
      return "\(name) at \(today) (usual \(usual))"
    }
    return name
  }

  // MARK: Portrait

  /// The portrait: what leads the headaches, their rhythm, and the clearest
  /// pattern.
  func portrait(_ facts: ProfileFacts) -> ProfilePortrait {
    let headline: String
    switch facts.leadingAreas.count {
    case 0: headline = facts.headaches > 0 ? "Your profile is taking shape" : "Nothing to profile yet"
    case 1: headline = "\(facts.leadingAreas[0]) leads your headaches"
    default: headline = "\(facts.leadingAreas[0]) and \(facts.leadingAreas[1].lowercased()) lead your headaches"
    }

    var sentences = [String]()
    if facts.headaches > 0 {
      let trend = facts.trend == "rising" ? ", and rising" : (facts.trend == "falling" ? ", and easing" : "")
      sentences.append("\(facts.headaches) \(facts.headaches == 1 ? "headache" : "headaches") in the last \(facts.windowDays) days, about \(facts.perMonth) a month\(trend).")
      var rhythm = [String]()
      if let start = facts.usualStart {
        rhythm.append("usually start \(start)")
      }
      if let day = facts.busiestDay {
        rhythm.append("most often on \(day)")
      }
      if let length = facts.typicalLength {
        rhythm.append("last about \(length)")
      }
      if !rhythm.isEmpty {
        sentences.append("They \(TemplateSummaryWriter.joined(rhythm)).")
      }
    }
    else {
      sentences.append("No headaches in the last \(facts.windowDays) days. Your patterns fill in as you log.")
    }
    if let pattern = facts.patterns.first {
      sentences.append("Your clearest pattern: \(pattern.pattern.prefix(1).lowercased() + pattern.pattern.dropFirst()).")
    }

    var lines = [String: String]()
    for pattern in facts.patterns {
      lines[pattern.id] = insightLine(for: pattern)
    }

    return ProfilePortrait(headline: headline, body: sentences.prefix(3).joined(separator: " "), insightLines: lines, isGenerated: false)
  }

  /// One pattern in plain words.
  func insightLine(for pattern: ProfileFacts.Pattern) -> String {
    var line = pattern.pattern
    if let lead = pattern.leadHours {
      line += ", most clearly about \(lead) hours ahead"
    }
    if let other = pattern.mayBeExplainedBy {
      line += " (may be explained by \(other.lowercased()))"
    }
    return line + "."
  }

  // MARK: Helpers

  /// "a", "a and b", "a, b, and c".
  static func joined(_ items: [String]) -> String {
    switch items.count {
    case 0: return ""
    case 1: return items[0]
    case 2: return "\(items[0]) and \(items[1])"
    default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
    }
  }

  /// The string with its first letter uppercased.
  static func capitalized(_ text: String) -> String {
    return text.prefix(1).uppercased() + text.dropFirst()
  }

}

/// Checks language-model prose before it reaches the screen: it must be short,
/// cite only numbers present in the facts, name only signals in the facts, and
/// stay clear of medical advice. Anything else falls back to the template.
/// Pure.
enum SummaryValidator {

  /// Phrases that turn a summary into advice.
  static let blockedPhrases = ["diagnos", "prescri", "dosage", "dose", "you should take", "cure", "emergency", "doctor", "physician", "causes your", "caused by"]

  /// Numbers always allowed (the forecast horizons).
  static let alwaysAllowedNumbers: Set<String> = ["12", "24"]

  /// Whether the text may be shown.
  ///
  /// - Parameters:
  ///   - text: The prose.
  ///   - grounding: The facts' rendered strings.
  ///   - signalNames: The signal names the facts mention.
  ///   - maxSentences: The most sentences allowed.
  ///   - maxCharacters: The most characters allowed.
  /// - Returns: Whether it passes.
  static func isValid(_ text: String, grounding: [String], signalNames: [String], maxSentences: Int, maxCharacters: Int) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= maxCharacters, sentenceCount(trimmed) <= maxSentences else {
      return false
    }

    let lower = trimmed.lowercased()
    guard !blockedPhrases.contains(where: { lower.contains($0) }) else {
      return false
    }

    let allowed = grounding.reduce(into: alwaysAllowedNumbers) { $0.formUnion(numbers(in: $1)) }
    guard numbers(in: trimmed).isSubset(of: allowed) else {
      return false
    }

    // A known signal named in the text must be one the facts mention.
    let known = signalNames.map({ $0.lowercased() }).joined(separator: " | ")
    for feature in CorrelationFeature.allCases {
      let title = feature.title.lowercased()
      if lower.contains(title) && !known.contains(title) {
        return false
      }
    }

    return true
  }

  /// The numbers in a string, as written ("5", "7.1").
  static func numbers(in text: String) -> Set<String> {
    let pattern = try? NSRegularExpression(pattern: "\\d+(?:[.,]\\d+)?")
    let range = NSRange(text.startIndex..., in: text)
    return Set((pattern?.matches(in: text, range: range) ?? []).compactMap { match in
      Range(match.range, in: text).map({ String(text[$0]) })
    })
  }

  /// The number of sentences.
  static func sentenceCount(_ text: String) -> Int {
    let pattern = try? NSRegularExpression(pattern: "[.!?](?:\\s|$)")
    let count = pattern?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0
    return max(count, 1)
  }

}
