//
//  WidgetDataSource.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import CoreData
import DataController
import Foundation

/// The lightweight reads a risk widget needs: the shared forecast, the current
/// severity, the current headache's start, the logged forecast history, and
/// the cached insights report. No `HeadacheManager` (which owns the predictor,
/// weather, HealthKit, and location managers), no inference, and no saves.
enum WidgetDataSource {

  /// The unresolved headache's severity and start, if one is in progress.
  struct CurrentHeadache {
    let severity: Headache.Severity
    let start: Date?
  }

  /// The headache in progress, if any — the same read the app uses, so the
  /// widgets can't disagree with the headache record. A read-only fetch.
  static func currentHeadache() async throws -> CurrentHeadache? {
    return try await DataController.shared.performInBackground(saveOnComplete: false) { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "resolved == NO")
      request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
      request.fetchLimit = 1
      guard let headache = try context.fetch(request).first else {
        return nil
      }
      return CurrentHeadache(severity: headache.severity ?? .unspecified, start: headache.startTime)
    }
  }

  /// The logged 24-hour forecasts over the trailing window, oldest first.
  ///
  /// - Parameters:
  ///   - hours: How far back to look.
  ///   - now: The reference moment.
  /// - Returns: The logged forecasts in time order.
  static func riskHistory(hours: Double = 48, now: Date = Date()) async throws -> [HeadacheManager.RiskHistoryPoint] {
    let cutoff = now.addingTimeInterval(-hours * 3600.0)
    return try await DataController.shared.performInBackground(saveOnComplete: false) { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "timestamp >= %@ AND horizonHours == %@ AND predictedProbability >= 0", cutoff as NSDate, NSNumber(value: 24))
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      request.returnsObjectsAsFaults = false
      return try context.fetch(request).compactMap { evaluation in
        guard let timestamp = evaluation.timestamp else {
          return nil
        }
        return HeadacheManager.RiskHistoryPoint(date: timestamp, probability: evaluation.predictedProbability)
      }
    }
  }

  /// The accuracy over resolved 24-hour forecasts, for the headline beside
  /// the confidence grade. A read-only fetch.
  ///
  /// - Returns: The accuracy and how many forecasts it covers, or nil when
  ///   none have resolved.
  static func observedAccuracy() async throws -> (accuracy: Double, count: Int)? {
    return try await DataController.shared.performInBackground(saveOnComplete: false) { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "resolved == YES AND horizonHours == %@ AND predictedProbability >= 0", NSNumber(value: 24))
      request.returnsObjectsAsFaults = false
      let points = try context.fetch(request).compactMap { evaluation -> EvaluationPoint? in
        guard let timestamp = evaluation.timestamp, let outcome = evaluation.actualOutcome else {
          return nil
        }
        return EvaluationPoint(date: timestamp, probability: evaluation.predictedProbability, outcome: outcome)
      }
      let summary = ProspectiveAccuracy.summary(points)
      guard let accuracy = summary.accuracy else {
        return nil
      }
      return (accuracy, summary.count)
    }
  }

  /// Everything a provider needs. Never throws: a failed fetch degrades to an
  /// empty history or an unknown headache start.
  ///
  /// - Parameter asOf: The moment the snapshot renders at.
  /// - Returns: The snapshot.
  static func loadSnapshot(asOf: Date = Date()) async -> RiskSnapshot {
    let shared = Preferences.Shared()
    let risk = shared.currentRisk

    // The headache record is the source of truth. The shared severity flag
    // can lag behind it (a headache resolved by an edit, a deletion, or the
    // launch repair pass never clears it), so it is only a fallback when the
    // store can't be read.
    var severity: Headache.Severity?
    var headacheStart: Date?
    do {
      if let current = try await currentHeadache() {
        severity = current.severity
        headacheStart = current.start
      }
    }
    catch {
      logError("Widget: error reading the current headache: \(error)")
      severity = shared.currentSeverity
    }

    var history = [HeadacheManager.RiskHistoryPoint]()
    do {
      history = try await riskHistory(now: asOf)
    }
    catch {
      logError("Widget: error reading the risk history: \(error)")
    }

    var observed: (accuracy: Double, count: Int)?
    do {
      observed = try await observedAccuracy()
    }
    catch {
      logError("Widget: error reading the observed accuracy: \(error)")
    }

    return RiskSnapshot(
      risk: risk,
      currentSeverity: severity,
      headacheStart: headacheStart,
      history: history,
      report: InsightsStore.shared.load(),
      observedAccuracy: observed,
      asOf: asOf)
  }

}
