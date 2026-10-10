//
//  AppleIntelligenceSummaryWriter.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The risk summary's guided-generation shape.
@Generable
struct RiskSummaryOutput {
  @Guide(description: "One or two short sentences, at most 30 words, explaining what is moving today's headache risk and, if given, when it peaks.")
  var text: String
}

/// One trigger pattern in plain words.
@Generable
struct PortraitLineOutput {
  @Guide(description: "The pattern's id, copied exactly from the facts.")
  var id: String
  @Guide(description: "One plain sentence, at most 20 words, saying what the pattern means in everyday terms.")
  var sentence: String
}

/// The portrait's guided-generation shape.
@Generable
struct PortraitOutput {
  @Guide(description: "Three to seven words naming what leads this person's headaches. No period.")
  var headline: String
  @Guide(description: "Two or three short sentences describing the person's headache patterns in plain language.")
  var body: String
  @Guide(description: "One entry per pattern in the facts.")
  var patterns: [PortraitLineOutput]
}

/// Writes the summaries with Apple's on-device language model. Every response
/// is validated against the facts; anything that fails, errors, or is refused
/// falls back to the template, so the screen never shows ungrounded prose.
struct AppleIntelligenceSummaryWriter: GenerativeSummaryWriter {

  /// The deterministic fallback.
  private let template = TemplateSummaryWriter()

  /// Whether the model can run right now.
  static var isAvailable: Bool {
    return SystemLanguageModel.default.isAvailable
  }

  /// Why the model can't run, for Settings.
  static var unavailableReason: String? {
    switch SystemLanguageModel.default.availability {
    case .available:
      return nil
    case .unavailable(.deviceNotEligible):
      return "This device doesn't support Apple Intelligence."
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Turn on Apple Intelligence in Settings to use it here."
    case .unavailable(.modelNotReady):
      return "Apple Intelligence is still getting ready on this device."
    case .unavailable:
      return "Apple Intelligence isn't available right now."
    }
  }

  /// Loads the model ahead of the first request.
  static func prewarm() {
    guard isAvailable else {
      return
    }
    LanguageModelSession(instructions: riskInstructions).prewarm()
  }

  // MARK: Instructions

  static let riskInstructions = """
  You write the short explanation under a headache-risk forecast in a personal headache tracking app.
  Rules:
  - One or two short sentences, at most 30 words in total.
  - Speak to the user as "you". Calm, plain, specific. No greeting, no emoji, no exclamation marks.
  - Use only the facts given. Never add a number, signal, cause, or suggestion that is not in the facts.
  - Say what is pushing the risk up or down, using today's value against the usual one when given, and when it concentrates if a timing is given.
  - The percent is a chance over the next 24 hours, not a certainty. Do not repeat the percent.
  - Never diagnose, never mention medication or doctors, never give advice.
  """

  static let portraitInstructions = """
  You write a short portrait of a person's headache patterns for the Profile screen of a headache tracking app.
  Rules:
  - Speak to the user as "you". Warm, plain, specific. No greeting, no emoji.
  - Use only the facts given. Never invent a number, signal, cause, or advice.
  - Patterns are associations, not causes: say "tends to come before" or "often follows", never "causes".
  - Never diagnose, never mention doctors, never suggest taking or changing medication.
  - Keep numbers exactly as written in the facts.
  """

  // MARK: GenerativeSummaryWriter

  func riskSummary(_ facts: RiskFacts) async -> SummaryText {
    let fallback = template.riskSummary(facts)
    do {
      let session = LanguageModelSession(instructions: AppleIntelligenceSummaryWriter.riskInstructions)
      let response = try await session.respond(
        to: "Facts:\n\(facts.summaryPromptJSON)\nWrite the explanation.",
        generating: RiskSummaryOutput.self,
        options: GenerationOptions(temperature: 0.3, maximumResponseTokens: 120))
      let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard SummaryValidator.isValid(text, grounding: facts.groundingStrings, signalNames: facts.signalNames, maxSentences: 2, maxCharacters: 220) else {
        logDebug("Generated risk summary failed validation; using the template.")
        return fallback
      }
      return SummaryText(text: text, isGenerated: true)
    }
    catch {
      logDebug("Risk summary generation failed: \(error)")
      return fallback
    }
  }

  func portrait(_ facts: ProfileFacts) async -> ProfilePortrait {
    let fallback = template.portrait(facts)
    do {
      let session = LanguageModelSession(instructions: AppleIntelligenceSummaryWriter.portraitInstructions)
      let response = try await session.respond(
        to: "Facts:\n\(facts.summaryPromptJSON)\nWrite the headline, a two-to-three sentence body, and one plain sentence per pattern.",
        generating: PortraitOutput.self,
        options: GenerationOptions(temperature: 0.4, maximumResponseTokens: 420))
      let output = response.content
      let grounding = facts.groundingStrings
      let names = facts.signalNames

      let headline = output.headline.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
      let body = output.body.trimmingCharacters(in: .whitespacesAndNewlines)
      guard SummaryValidator.isValid(headline, grounding: grounding, signalNames: names, maxSentences: 1, maxCharacters: 60),
            SummaryValidator.isValid(body, grounding: grounding, signalNames: names, maxSentences: 3, maxCharacters: 420) else {
        logDebug("Generated portrait failed validation; using the template.")
        return fallback
      }

      // Each pattern line stands alone: a bad one falls back individually.
      var lines = fallback.insightLines
      for line in output.patterns {
        guard lines[line.id] != nil else {
          continue
        }
        let sentence = line.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if SummaryValidator.isValid(sentence, grounding: grounding, signalNames: names, maxSentences: 1, maxCharacters: 160) {
          lines[line.id] = sentence
        }
      }

      return ProfilePortrait(headline: headline, body: body, insightLines: lines, isGenerated: true)
    }
    catch {
      logDebug("Portrait generation failed: \(error)")
      return fallback
    }
  }

}
#endif
