//
//  UITestSupport.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

#if DEBUG
import CoreData
import DataController
import Foundation
import SwiftUI

/// Launch-argument hooks that seed a representative dataset for the
/// screenshot-sweep UI test, so every card-based screen renders with real
/// content. DEBUG-only; never ships. Activated by `--uitest-seed`, with an
/// optional `--uitest-theme <name>` override.
enum UITestSupport {

  /// Whether the launch requested seeded UI-test data.
  static var isSeedingRequested: Bool {
    return CommandLine.arguments.contains("--uitest-seed")
  }

  /// Applies a theme override synchronously (before views render).
  static func applyLaunchOverrides() {
    guard isSeedingRequested else {
      return
    }

    guard let index = CommandLine.arguments.firstIndex(of: "--uitest-theme"),
          index + 1 < CommandLine.arguments.count else {
      return
    }
    let name = CommandLine.arguments[index + 1].lowercased()
    if let theme = ColorTheme.allCases.first(where: { $0.name.lowercased() == name }) {
      var general = Preferences.General()
      general.colorTheme = theme
    }
  }

  /// Seeds headaches, exposures, medications, a cached insights report, and
  /// a sample risk into the live store.
  static func seedIfNeeded() async {
    guard isSeedingRequested else {
      return
    }

    do {
      try await seed()
    }
    catch {
      logError("UI-test seeding failed: \(error)")
    }

    // Sample risk for the Track risk / "Why" cards.
    var shared = Preferences.Shared()
    shared.currentRisk = Previewing.Prediction.prediction
    NotificationCenter.default.post(name: Preferences.predictionDidChangeNotification, object: nil)

    seedInsightsReport()
  }

  // MARK: Private methods

  private static func seed() async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Idempotent: clear the user entities first. Delete through the
      // context (not a batch request) so the view context stays consistent.
      for entity in ["Headache", "Tag", "Exposure", "MedicationEntry", "TrainingData", "Evaluation"] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        for object in (try? context.fetch(request)) ?? [] {
          context.delete(object)
        }
      }

      let now = Date()
      let calendar = Calendar.current

      // Eight resolved headaches spread across the last month, varied
      // severity and type — populates the Headaches list, Analyze graphs,
      // and statistics.
      let recipes: [(daysAgo: Int, peak: Headache.Severity, type: Headache.Types)] = [
        (1, .severe, .migraine),
        (3, .moderate, .tension),
        (6, .mild, .tension),
        (9, .severe, .migraine),
        (13, .moderate, .cluster),
        (18, .mild, .tension),
        (24, .moderate, .migraine),
        (29, .severe, .cluster)
      ]

      var recentHeadache: Headache?
      for recipe in recipes {
        let start = calendar.date(byAdding: .day, value: -recipe.daysAgo, to: now) ?? now
        let headache = Headache(context: context, severity: .mild, classification: .primary, type: recipe.type, start: start)
        headache.addSeverity(recipe.peak, start: start.addingTimeInterval(1800.0))
        headache.addSeverity(.moderate, start: start.addingTimeInterval(5400.0))
        // Close the final severity so the launch repair pass keeps the
        // headache resolved (unresolved iff the last severity is open).
        headache.severitiesArray.last?.endTime = start.addingTimeInterval(9000.0)
        headache.resolved = true
        if recentHeadache == nil {
          recentHeadache = headache
        }
      }

      // The most recent resolved headache gets tags + a medication so its
      // detail view exercises every card.
      if let headache = recentHeadache {
        for value in ["right-side", "throbbing", "aura"] {
          let tag = Tag(context: context)
          tag.value = value
          headache.addToTags(tag)
        }

        let medication = MedicationEntry(context: context, name: "Sumatriptan", takenAt: headache.startTime?.addingTimeInterval(2400.0) ?? now)
        medication.efficacy = .helpful
        headache.addToMedications(medication)
      }

      // Today's exposures for the check-in card.
      for kind in ["caffeine", "stress", "poor-hydration"] {
        let exposure = Exposure(context: context)
        exposure.identifier = UUID()
        exposure.kindRaw = kind
        exposure.timestamp = calendar.startOfDay(for: now).addingTimeInterval(43200.0)
      }
    }
  }

  private static func seedInsightsReport() {
    let insights: [TriggerInsight] = [
      TriggerInsight(
        feature: .sleepSeconds, target: .occurrence, coefficient: -0.58, qValue: 0.004,
        bestLagHours: 24, lagProfile: [6: -0.2, 12: -0.35, 24: -0.58, 48: -0.3],
        sampleCount: 96, eventCount: 22, positiveMean: 5.2 * 3600.0, baselineMean: 7.1 * 3600.0,
        usesBaselineRelative: true, explainedBy: nil, partialCoefficient: nil),
      TriggerInsight(
        feature: .sigmaPressure, target: .occurrence, coefficient: 0.41, qValue: 0.03,
        bestLagHours: 12, lagProfile: [6: 0.3, 12: 0.41, 24: 0.25, 48: 0.1],
        sampleCount: 88, eventCount: 19, positiveMean: 0.9, baselineMean: 0.3,
        usesBaselineRelative: true, explainedBy: nil, partialCoefficient: nil),
      TriggerInsight(
        feature: .exposureCaffeine, target: .occurrence, coefficient: 0.33, qValue: 0.08,
        bestLagHours: 24, lagProfile: [24: 0.33], sampleCount: 61, eventCount: 14,
        positiveMean: 2.1, baselineMean: 1.0, usesBaselineRelative: false,
        explainedBy: .exposurePoorHydration, partialCoefficient: 0.12)
    ]

    // rowCount/exposureCount must match the store (no TrainingData seeded,
    // three exposures) so HeadacheManager.insights() treats the cache as
    // fresh instead of recomputing it to empty.
    let report = InsightsReport(
      generatedAt: Date(),
      rowCount: 0,
      exposureCount: 3,
      insights: insights,
      insufficient: [
        InsightsReport.InsufficientFeature(feature: .menstrualDaysSinceCycleStart, sampleCount: 12)
      ],
      baselines: [
        .sleepSeconds: FeatureBaseline(mean: 7.1 * 3600.0, std: 3600.0, count: 30),
        .sigmaPressure: FeatureBaseline(mean: 0.3, std: 0.2, count: 30)
      ],
      schemaVersion: InsightsReport.currentSchemaVersion)

    InsightsStore.shared.save(report)
  }

}
#endif
