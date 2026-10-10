//
//  SummaryService.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import ApplicationKey
import Foundation
import SwiftUI

/// Caches generated summaries in the app group, keyed by the hash of the facts
/// they were written from, so a summary is only rewritten when its facts
/// change. Template summaries are never cached: they're free to recompute.
final class SummaryStore {

  static let shared = SummaryStore()

  /// Bump to drop every cached summary (instructions or facts changed).
  static let schemaVersion = 1

  /// The most risk summaries kept.
  static let riskCapacity = 8

  /// The longest a portrait is reused for the same facts.
  static let portraitLifetime: TimeInterval = 86400.0

  private struct Contents: Codable {
    var schemaVersion = SummaryStore.schemaVersion
    var risk = [String: SummaryText]()
    var riskOrder = [String]()
    var portraitKey: String?
    var portrait: ProfilePortrait?
    var portraitDate: Date?
  }

  private var contents: Contents?
  private let queue = DispatchQueue(label: ApplicationKey(from: "summaryStoreQueue"))

  private var fileURL: URL {
    let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return container.appendingPathComponent("summaries.json")
  }

  private func loaded() -> Contents {
    if let contents = contents {
      return contents
    }
    let decoded = (try? Data(contentsOf: fileURL)).flatMap({ try? JSONDecoder().decode(Contents.self, from: $0) })
    let fresh = decoded.flatMap({ $0.schemaVersion == SummaryStore.schemaVersion ? $0 : nil }) ?? Contents()
    contents = fresh
    return fresh
  }

  private func persist(_ contents: Contents) {
    self.contents = contents
    if let data = try? JSONEncoder().encode(contents) {
      try? data.write(to: fileURL, options: .atomic)
    }
  }

  /// The cached risk summary for the facts' key.
  func risk(for key: String) -> SummaryText? {
    return queue.sync { loaded().risk[key] }
  }

  /// Caches a generated risk summary.
  func save(risk: SummaryText, for key: String) {
    queue.sync {
      var contents = loaded()
      contents.risk[key] = risk
      contents.riskOrder.removeAll(where: { $0 == key })
      contents.riskOrder.append(key)
      while contents.riskOrder.count > SummaryStore.riskCapacity {
        contents.risk.removeValue(forKey: contents.riskOrder.removeFirst())
      }
      persist(contents)
    }
  }

  /// The cached portrait for the facts' key, while it's fresh.
  func portrait(for key: String, now: Date = Date()) -> ProfilePortrait? {
    return queue.sync {
      let contents = loaded()
      guard contents.portraitKey == key, let date = contents.portraitDate, now.timeIntervalSince(date) < SummaryStore.portraitLifetime else {
        return nil
      }
      return contents.portrait
    }
  }

  /// Caches a generated portrait.
  func save(portrait: ProfilePortrait, for key: String, now: Date = Date()) {
    queue.sync {
      var contents = loaded()
      contents.portraitKey = key
      contents.portrait = portrait
      contents.portraitDate = now
      persist(contents)
    }
  }

  /// Drops every cached summary.
  func removeAll() {
    queue.sync { persist(Contents()) }
  }

}

/// Serves the Track and Profile summaries: the cached generated text when the
/// facts haven't changed, else the template immediately and the language
/// model's rewrite when it arrives.
@MainActor
final class SummaryService: ObservableObject {

  /// Whether generated summaries can run.
  enum Availability: Equatable {
    case available
    case turnedOff
    case unavailable(String)
  }

  /// The Track tab's risk summary.
  @Published private(set) var risk: SummaryText?

  /// The Profile tab's portrait.
  @Published private(set) var portrait: ProfilePortrait?

  /// Whether the model is rewriting the risk summary.
  @Published private(set) var isWritingRisk = false

  /// Whether the model is rewriting the portrait.
  @Published private(set) var isWritingPortrait = false

  private var riskKey: String?
  private var portraitKey: String?
  private let store = SummaryStore.shared
  private let template = TemplateSummaryWriter()

  /// Whether generated summaries can run, and why not.
  var availability: Availability {
    guard Preferences.General().aiSummaries else {
      return .turnedOff
    }
    #if canImport(FoundationModels)
    if let reason = AppleIntelligenceSummaryWriter.unavailableReason {
      return .unavailable(reason)
    }
    return .available
    #else
    return .unavailable("Apple Intelligence isn't available in this build.")
    #endif
  }

  /// The writer that rewrites the templates, when one can run.
  private var generativeWriter: GenerativeSummaryWriter? {
    #if DEBUG
    if UITestSupport.isSeedingRequested {
      return UITestSummaryWriter()
    }
    #endif
    guard availability == .available else {
      return nil
    }
    #if canImport(FoundationModels)
    return AppleIntelligenceSummaryWriter()
    #else
    return nil
    #endif
  }

  /// Loads the model ahead of the first request.
  func prewarm() {
    #if canImport(FoundationModels)
    if availability == .available {
      AppleIntelligenceSummaryWriter.prewarm()
    }
    #endif
  }

  /// Forgets the current keys so the next update rewrites (after the setting
  /// changes).
  func invalidate() {
    riskKey = nil
    portraitKey = nil
  }

  /// Serves the risk summary for the facts.
  ///
  /// - Parameter facts: The facts, or nil without a forecast.
  func update(risk facts: RiskFacts?) {
    guard let facts = facts else {
      riskKey = nil
      risk = nil
      isWritingRisk = false
      return
    }

    let key = facts.summaryCacheKey
    guard key != riskKey else {
      return
    }
    riskKey = key

    if generativeWriter != nil, let cached = store.risk(for: key) {
      risk = cached
      return
    }

    risk = template.riskSummary(facts)
    guard let writer = generativeWriter else {
      isWritingRisk = false
      return
    }

    isWritingRisk = true
    Task {
      let written = await writer.riskSummary(facts)
      guard self.riskKey == key else {
        return
      }
      if written.isGenerated {
        self.store.save(risk: written, for: key)
      }
      withAnimation(Tokens.Motion.reveal) {
        self.risk = written
        self.isWritingRisk = false
      }
    }
  }

  /// Serves the portrait for the facts.
  ///
  /// - Parameter facts: The facts.
  func update(portrait facts: ProfileFacts) {
    let key = facts.summaryCacheKey
    guard key != portraitKey else {
      return
    }
    portraitKey = key

    if generativeWriter != nil, let cached = store.portrait(for: key) {
      portrait = cached
      return
    }

    portrait = template.portrait(facts)
    guard let writer = generativeWriter else {
      isWritingPortrait = false
      return
    }

    isWritingPortrait = true
    Task {
      let written = await writer.portrait(facts)
      guard self.portraitKey == key else {
        return
      }
      if written.isGenerated {
        self.store.save(portrait: written, for: key)
      }
      withAnimation(Tokens.Motion.reveal) {
        self.portrait = written
        self.isWritingPortrait = false
      }
    }
  }

}

#if DEBUG
/// The screenshot sweep's stand-in for the language model: the template's
/// prose, marked as generated so the sweep captures the generated styling.
/// The simulator has no Apple Intelligence model.
struct UITestSummaryWriter: GenerativeSummaryWriter {

  func riskSummary(_ facts: RiskFacts) async -> SummaryText {
    return SummaryText(text: TemplateSummaryWriter().riskSummary(facts).text, isGenerated: true)
  }

  func portrait(_ facts: ProfileFacts) async -> ProfilePortrait {
    let portrait = TemplateSummaryWriter().portrait(facts)
    return ProfilePortrait(headline: portrait.headline, body: portrait.body, insightLines: portrait.insightLines, isGenerated: true)
  }

}
#endif
