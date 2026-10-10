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

  /// Seeds headaches, medications, a cached insights report, and a sample
  /// risk into the live store.
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

    // Sample risk for the Track risk / "Why" cards and the widgets.
    var shared = Preferences.Shared()
    var prediction = Previewing.Prediction.prediction
    prediction.shortProbability = 0.31
    shared.currentRisk = prediction
    NotificationCenter.default.post(name: Preferences.predictionDidChangeNotification, object: nil)

    seedInsightsReport()
    WidgetReloader.reloadAll()
  }

  // MARK: Private methods

  private static func seed() async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Idempotent: clear the user entities first. Delete through the
      // context (not a batch request) so the view context stays consistent.
      for entity in ["Headache", "Tag", "MedicationEntry", "TrainingData", "Evaluation"] {
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

      // An in-progress headache for the active-headache capture.
      if CommandLine.arguments.contains("--uitest-active-headache") {
        let start = now.addingTimeInterval(-70.0 * 60.0)
        let headache = Headache(context: context, severity: .mild, classification: .primary, type: .migraine, start: start)
        headache.addSeverity(.moderate, start: start.addingTimeInterval(1500.0))
        headache.resolved = false
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

      // Training rows behind the trigger-detail time series. Four readings a
      // day over the last 90 days, minus a deliberate week-long hole so the
      // chart's gap handling is visible in the sweep rather than only in unit
      // tests.
      for daysAgo in stride(from: 90, through: 0, by: -1) where !(40 ... 47).contains(daysAgo) {
        guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else {
          continue
        }
        for reading in 0 ..< 4 {
          let timestamp = day.addingTimeInterval(Double(reading) * 6.0 * 3600.0)
          let trainingData = TrainingData(context: context)
          trainingData.timestamp = timestamp
          // A slow drift plus a wobble, so daily means actually move.
          let hours = 7.0 + sin(Double(daysAgo) / 6.0) * 1.2 + Double(reading % 3) * 0.15
          trainingData.updateWithHealthKitData([.sleepSeconds: hours * 3600.0], at: timestamp)
        }
      }

      // Dense recent forecasts behind the widgets' 48-hour sparkline: hourly,
      // ending twenty minutes ago, on the same gentle curve the widget
      // samples use.
      for point in RiskSnapshot.Samples.history(endingAt: 0.42, asOf: now) {
        let evaluation = Evaluation(context: context)
        evaluation.timestamp = point.date
        evaluation.horizonHours = 24
        evaluation.predictedProbability = point.probability
        evaluation.predictedOutlookRaw = point.probability >= 0.5 ? Outlook.possibleHeadache.rawValue : Outlook.noHeadache.rawValue
        evaluation.resolveAfter = point.date.addingTimeInterval(86400.0)
        evaluation.resolved = false
      }

      // Resolved forecasts behind the Analyze tab's accuracy card: four a day
      // over the last 60 days, mostly right, with a rough patch in the middle
      // so the trend line visibly dips.
      for daysAgo in stride(from: 60, through: 2, by: -1) {
        guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else {
          continue
        }
        for reading in 0 ..< 4 {
          let index = daysAgo * 4 + reading
          let outcome = index % 6 == 0
          let roughPatch = (25 ... 32).contains(daysAgo)
          let correct = roughPatch ? index % 2 == 0 : index % 5 != 0
          let evaluation = Evaluation(context: context)
          evaluation.timestamp = day.addingTimeInterval(Double(reading) * 6.0 * 3600.0)
          evaluation.horizonHours = 24
          evaluation.predictedProbability = (outcome == correct) ? 0.78 : 0.18
          evaluation.predictedOutlookRaw = (outcome == correct) ? Outlook.possibleHeadache.rawValue : Outlook.noHeadache.rawValue
          evaluation.resolveAfter = evaluation.timestamp?.addingTimeInterval(86400.0)
          evaluation.resolved = true
          evaluation.outlook = correct
          evaluation.actualOutcome = outcome
        }
      }
    }
  }

  /// The number of seeded training rows, which `seedInsightsReport` must
  /// report so `insights()` treats the cached report as fresh.
  private static var seededTrainingRowCount: Int {
    return stride(from: 90, through: 0, by: -1).filter({ !(40 ... 47).contains($0) }).count * 4
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
        usesBaselineRelative: true, explainedBy: nil, partialCoefficient: nil)
    ]

    // rowCount must match the seeded store so HeadacheManager.insights()
    // treats the cache as fresh instead of recomputing it to empty.
    let report = InsightsReport(
      generatedAt: Date(),
      rowCount: seededTrainingRowCount,
      insights: insights,
      insufficient: [
        InsightsReport.InsufficientFeature(feature: .menstrualDaysSinceCycleStart, sampleCount: 12)
      ],
      baselines: [
        .sleepSeconds: FeatureBaseline(mean: 7.1 * 3600.0, std: 3600.0, count: 30),
        .sigmaPressure: FeatureBaseline(mean: 0.3, std: 0.2, count: 30)
      ],
      schemaVersion: InsightsReport.currentSchemaVersion,
      // Must match the live preferences, or `insights()` reads the seed as
      // stale and recomputes it to empty — blanking the screenshot sweep.
      enabledFingerprint: InsightsReport.fingerprint(for: Preferences.Predictors().enabledCorrelationFeatures()))

    InsightsStore.shared.save(report)
  }

}
#endif
