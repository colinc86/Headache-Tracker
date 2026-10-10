//
//  HeadacheManager.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import CoreData
import CoreLocation
import DataController
import Foundation
import SwiftUI
import WidgetKit

class HeadacheManager: ObservableObject {
  
  enum HeadacheError: Error, CustomStringConvertible {
    case testing
    case missing
    case headacheDateRange
    case alreadyActive

    var description: String {
      switch self {
      case .testing:
        return "This operation is not allowed in test mode."
      case .missing:
        return "The required data was missing."
      case .headacheDateRange:
        return "The headache's onset must be before its end."
      case .alreadyActive:
        return "A headache is already in progress. Resolve it before starting another."
      }
    }
  }
  
  enum DeleteDisposition: String, CaseIterable, Identifiable {
    
    typealias ObjectIdentifier = RawValue
    
    var id: ObjectIdentifier {
      rawValue
    }
    
    case always
    case never
    case ask
  }
  
  // MARK: Public properties
  
  /// The manager's weather manager.
  let weatherManager = WeatherManager()
  
  /// The health kit manager to use when authorizing health kit and sharing/reading data.
  let healthKitManager = HealthKitManager()
  
  /// The headache predictor.
  let predictor = Predictor()

  /// Whether a training-data upgrade pass is running.
  private var isUpgradingTrainingData = false
  
  /// The manager's location manager.
  let locationManager = LocationManager()
  
  // MARK: Private properties
  
  /// The app's preferences.
  private var preferences = Preferences()

}

// MARK: - Current headache methods

extension HeadacheManager {
  
  /// Changes the manager's severity and either creates a new headache, or adds the new
  /// severity to the current headache.
  ///
  /// - Parameter severity: The headache's current severity.
  func changeSeverity(to severity: Headache.Severity) async throws {
    logDebug("Change severity to \(severity.title).")

    // Selecting "not present" means the headache is over; resolve it instead
    // of leaving it open with a not-present severity.
    guard severity != .notPresent else {
      try await resolve()
      return
    }

    let classification = preferences.headaches.defaultHeadacheClassification
    let type = preferences.headaches.defaultHeadacheType

    // The date interval of the severity to save to health kit
    let severityUpdates: Headache.SeverityUpdates = try await currentHeadache { headache, context in
      // Add to the current headache or create a new one
      if let headache = headache {
        logDebug("Adding severity to current headache.")
        return headache.addSeverity(severity, start: Date())
      }

      logDebug("Creating new headache.")
      _ = Headache(context: context, severity: severity, classification: classification, type: type, start: Date())
      return .empty
    }
    
    // If there wasn't an error, then update the widget data and continue
    preferences.shared.setCurrentSeverity(severity)
    
    // Write the data to health kit and set our check-in alert
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
    
    // Update the CoreML training data
    try await createPredict(create: .always(.userAction), inWidget: false)
  }
  
  /// Resolves the headache.
  func resolve() async throws {
    logDebug("Resolve headache.")
    
    // Get the current headache
    let severityUpdates: Headache.SeverityUpdates = try await currentHeadache { headache, context in
      // Resolve the headache
      if let headache = headache {
        return headache.resolve(end: Date())
      }
      else {
        logWarning("No current headache to resolve.")
      }
      return .empty
    }
    
    // If there wasn't an error, then update the widget data and continue
    preferences.shared.setCurrentSeverity(nil)
    
    // Write the data to health kit
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
    
    // Update the CoreML models
    try await createPredict(create: .always(.userAction), inWidget: false)
  }
  
}

// MARK: - Object management methods

extension HeadacheManager {
  
  /// Creates a headache with the given starting severity.
  ///
  /// - Parameters:
  ///   - severity: The headache's starting severity.
  ///   - startTime: The headache's start time.
  ///   - endTime: The headache's end time.
  func createHeadache(severity: Headache.Severity, start: Date, end: Date?) async throws {
    if let end = end {
      guard start < end else {
        throw HeadacheError.headacheDateRange
      }
    }

    let classification = preferences.headaches.defaultHeadacheClassification
    let type = preferences.headaches.defaultHeadacheType

    let intervals: [Headache.Severity.Interval] = try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Only one headache may be open at a time.
      if end == nil {
        let request = Headache.fetchRequest()
        request.predicate = NSPredicate(format: "resolved = NO")
        request.fetchLimit = 1
        if try context.fetch(request).first != nil {
          throw HeadacheError.alreadyActive
        }
      }

      let headache = Headache(context: context, severity: severity, classification: classification, type: type, start: start, end: end)
      // Value-type intervals for the closed severities (open ones yield nil).
      return headache.severitiesArray.compactMap({ $0.severityInterval })
    }

    // A new open headache becomes the current one — mirror it to the shared
    // severity so the widgets reflect it, matching the interactive change path.
    if end == nil {
      preferences.shared.setCurrentSeverity(severity)
    }

    // Mirror the closed severity intervals to HealthKit, matching
    // `changeSeverity`/`resolve` — a headache added here was otherwise never
    // written to the Health app. (No-ops for an open headache: no closed
    // intervals yet.)
    try await healthKitManager.saveSeveritySamples(intervals: intervals)

    // Create the training data
    let input = await predictorInput(atDate: start, inWidget: false)
    try await createTrainingData(from: input, source: .backdated)
  }
  
  /// Adds a new severity to the headache with the given identifier.
  ///
  /// - Parameter identifier: The headache's identifier.
  func addSeverityToHeadache(identifier: UUID) async throws {
    logDebug("Add severity.")
    
    // Get the headache
    let severityUpdates: Headache.SeverityUpdates = try await headacheWithIdentifier(identifier: identifier) { headache, context in
      if let headache = headache {
        return headache.addSeverity(.notPresent, duration: 3600.0)
      }
      return .empty
    }
    
    // Create the training data
    if let startTime = severityUpdates.createdSeverityStartTime {
      let input = await predictorInput(atDate: startTime, inWidget: false)
      try await createTrainingData(from: input, source: .backdated)
    }
    
    // Update the health kit samples
    if let interval = severityUpdates.updatedSeverityInterval {
      try await healthKitManager.saveSeveritySamples(intervals: [interval])
    }
  }
  
  /// Updates the headache's type.
  ///
  /// - Parameters:
  ///   - type: The new type.
  ///   - classification: The new classification.
  ///   - identifier: The headache's identifier.
  func updateHeadacheType(_ type: Headache.Types, classification: Headache.Classification, identifier: UUID) async throws {
    logDebug("Set type.")
    
    try await headacheWithIdentifier(identifier: identifier) { headache, _ in
      headache?.headacheType = type
      headache?.headacheClassification = classification
    }
  }
  
  /// Updates the headache's notes.
  ///
  /// - Parameters:
  ///   - notes: The headache's notes.
  ///   - identifier: The headache's identifier.
  func updateHeadacheNotes(_ notes: String?, identifier: UUID) async throws {
    logDebug("Set notes.")
    
    // Get the headache and update its notes
    try await headacheWithIdentifier(identifier: identifier) { headache, _ in
      headache?.notes = notes
    }
  }
  
  /// Updates the headache's tags.
  ///
  /// - Parameters:
  ///   - tags: The headache's tags.
  ///   - identifier: The headache's identifier.
  func updateHeadacheTags(_ tags: [String], identifier: UUID) async throws {
    logDebug("Set tags.")
    
    // Get the headache and update its tags
    try await headacheWithIdentifier(identifier: identifier) { headache, context in
      guard let headache = headache else {
        return
      }

      // Remove the headache tags that don't need to be there
      for tag in headache.tagsArray where !tags.contains(tag.value ?? "") {
        // Remove the tag from the headache
        headache.removeFromTags(tag)
        
        // Remove the headache from the tag
        tag.removeFromHeadaches(headache)
        
        // If the tag isn't part of any other headache, delete it
        if tag.headaches?.count == 0 {
          context.delete(tag)
        }
      }
      
      // Add the new tags
      for tag in tags where !headache.tagsArray.contains(where: { $0.value == tag }) {
        // See if the tag already exists
        let request = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "value = %@", tag)
        
        if let existingTag = (try context.fetch(request)).first {
          // It already exists, so add it to the headache
          headache.addToTags(existingTag)
          existingTag.addToHeadaches(headache)
        }
        else {
          // It doesn't already exist, so create a new tag
          let newTag = Tag(context: context)
          newTag.value = tag
          headache.addToTags(newTag)
          newTag.addToHeadaches(headache)
        }
      }
    }
  }
  
  /// Deletes the headache with the given identifier and it's associated health kit data.
  ///
  /// - Parameters:
  ///   - identifier: The headache's identifier.
  ///   - deleteHealthKitData: Whether we should also delete the headache's health kit data.
  func deleteHeadache(identifier: UUID?, deleteHealthKitData: Bool) async throws {
    logDebug("Delete headache.")
    guard let identifier = identifier else {
      return
    }
    
    // The interval and severities to delete from health kit
    var headacheInterval: DateInterval?
    var severityIdentifiers = [UUID]()

    try await headacheWithIdentifier(identifier: identifier) { [weak self] headache, context in
      logDebug("Deleting headache.")

      // Get the headache
      if let headache = headache {
        // Remove the headache from its tags
        for tag in headache.tagsArray {
          tag.removeFromHeadaches(headache)
          if tag.headaches?.count == 0 {
            context.delete(tag)
          }
        }

        // Delete the headache
        headacheInterval = headache.dateInterval
        severityIdentifiers = headache.severitiesArray.compactMap({ $0.identifier })
        context.delete(headache)

        // If this headache was the current headache, then cancel any pending check-in notifications
        // and reset the current severity.
        if !headache.resolved {
          self?.preferences.shared.setCurrentSeverity(nil)
        }
      }
    }

    // If there wasn't an error, then we should check and delete it from health kit
    if deleteHealthKitData, let headacheInterval = headacheInterval {
      logDebug("Successfully reset headache. Deleting severity samples.")
      try await healthKitManager.deleteSeveritySamples(in: headacheInterval, severityIdentifiers: severityIdentifiers)
    }
    else {
      logDebug("Successfully reset headache, but not deleting severity samples.")
    }
  }
  
  /// Deletes the severity with the given identifier.
  ///
  /// - Parameter identifier: The severity's identifier.
  func deleteSeverity(identifier: UUID?) async throws {
    logDebug("Delete severity.")
    guard let identifier = identifier else {
      return
    }
    
    var originalHeadacheInterval: DateInterval?
    var originalSeverityIdentifiers = [UUID]()
    var newSeveritySamples = [Headache.Severity.Interval]()

    try await severityWithIdentifier(identifier: identifier) { severity, context in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        originalSeverityIdentifiers = (headache?.severitiesArray ?? []).compactMap({ $0.identifier })
        headache?.removeFromSeverities(severity)
        context.delete(severity)
        headache?.reorganize()

        // Deleting the open severity may have left the headache with only
        // closed intervals; keep the resolved flag consistent with the
        // open-interval invariant.
        if let headache = headache, !headache.severitiesArray.isEmpty {
          headache.resolved = headache.severitiesArray.last?.endTime != nil
        }

        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    }

    // Check to see if we need to delete and re-add samples
    if let originalHeadacheInterval = originalHeadacheInterval {
      try await healthKitManager.deleteSeveritySamples(in: originalHeadacheInterval, severityIdentifiers: originalSeverityIdentifiers)
      try await healthKitManager.saveSeveritySamples(intervals: newSeveritySamples)
    }

    // Editing a severity can change (or clear) the active headache's current
    // severity — mirror it to the shared widget defaults, as the other write
    // paths do, so the severity widget and watch don't show a stale value.
    try await refreshSharedState()
  }
  
  /// Updates the severity with the given identifier.
  ///
  /// - Parameter identifier: The severity's identifier.
  func updateSeverity(identifier: UUID, value: Headache.Severity, startTime: Date, endTime: Date) async throws {
    logDebug("Update severity.")

    guard startTime < endTime else {
      throw HeadacheError.headacheDateRange
    }

    var originalHeadacheInterval: DateInterval?
    var originalSeverityIdentifiers = [UUID]()
    var newSeveritySamples = [Headache.Severity.Interval]()

    try await severityWithIdentifier(identifier: identifier) { (severity, context) in
      if let severity = severity {
        let headache = severity.headache
        originalHeadacheInterval = headache?.dateInterval
        originalSeverityIdentifiers = (headache?.severitiesArray ?? []).compactMap({ $0.identifier })
        severity.severity = value
        severity.startTime = startTime
        severity.endTime = endTime
        headache?.reorganize()

        // Editing may have closed (or reopened) the last severity; keep the
        // resolved flag consistent with the open-interval invariant.
        if let headache = headache {
          headache.resolved = headache.severitiesArray.last?.endTime != nil
        }

        for severity in headache?.severitiesArray ?? [] {
          guard let interval = severity.severityInterval else { continue }
          newSeveritySamples.append(interval)
        }
      }
    }

    // Check to see if we need to delete and re-add samples
    if let originalHeadacheInterval = originalHeadacheInterval {
      try await healthKitManager.deleteSeveritySamples(in: originalHeadacheInterval, severityIdentifiers: originalSeverityIdentifiers)
      try await healthKitManager.saveSeveritySamples(intervals: newSeveritySamples)
    }

    // Editing a severity can change (or clear) the active headache's current
    // severity — mirror it to the shared widget defaults, as the other write
    // paths do, so the severity widget and watch don't show a stale value.
    try await refreshSharedState()
  }
  
}

// MARK: - Insights

extension HeadacheManager {

  /// Builds correlation samples and headache episodes, runs the correlation
  /// engine outside of any managed object context, and caches the report.
  ///
  /// - Returns: The freshly computed report.
  @discardableResult
  func computeInsights() async throws -> InsightsReport {
    let (samples, episodes, totalRowCount) = try await DataController.shared.performInBackground { context -> ([CorrelationSample], [HeadacheEpisode], Int) in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      let trainingData = try context.fetch(request)
      let samples = trainingData.compactMap({ $0.correlationSample })
      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      return (samples, episodes, trainingData.count)
    }

    // Only the predictors the user has left enabled. Historical rows keep
    // their values for a disabled metric, so without this the engine would
    // keep generating insights from frozen history after the toggle went off.
    let enabledFeatures = Preferences.Predictors().enabledCorrelationFeatures()

    logInfo("Computing insights from \(samples.count) samples and \(episodes.count) episodes across \(enabledFeatures.count) enabled features.")
    let engine = CorrelationEngine(samples: samples, episodes: episodes, enabledFeatures: enabledFeatures)
    let computed = engine.computeReport()

    // Store the total row count — the same number insights() compares against
    // for staleness. Using the filtered sample count instead made the cache
    // permanently stale when any row lacked usable values.
    let report = InsightsReport(
      generatedAt: computed.generatedAt,
      rowCount: totalRowCount,
      insights: computed.insights,
      insufficient: computed.insufficient,
      baselines: computed.baselines,
      schemaVersion: computed.schemaVersion,
      enabledFingerprint: computed.enabledFingerprint)
    InsightsStore.shared.save(report)
    return report
  }

  /// The latest insights report, recomputing when stale.
  ///
  /// - Returns: The report.
  func insights() async throws -> InsightsReport {
    let rowCount = try await trainingDataCount()
    let fingerprint = InsightsReport.fingerprint(for: Preferences.Predictors().enabledCorrelationFeatures())
    if InsightsStore.shared.isStale(rowCount: rowCount, enabledFingerprint: fingerprint) {
      return try await computeInsights()
    }
    if let report = InsightsStore.shared.load() {
      return report
    }
    return try await computeInsights()
  }

  /// The dated series of a feature's values along with all headache
  /// episodes, for the trigger detail chart.
  ///
  /// - Parameter feature: The feature.
  /// - Returns: The feature's series and the headache episodes.
  /// - Parameters:
  ///   - feature: The feature to chart.
  ///   - baselineRelative: Whether to chart personal-baseline z-scores rather
  ///     than raw values. Pass the insight's `usesBaselineRelative` so the
  ///     chart shows the same representation the correlation was computed on.
  ///   - window: How far back to chart.
  func featureSeries(
    for feature: CorrelationFeature,
    baselineRelative: Bool = false,
    window: TimeInterval = 180.0 * 86400.0
  ) async throws -> ([DatedValue], [HeadacheEpisode]) {
    return try await DataController.shared.performInBackground { context in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      let trainingData = try context.fetch(request)

      let samples = trainingData.compactMap({ $0.correlationSample })

      var timestamps = [Date]()
      var values = [Double]()
      for sample in samples {
        guard let value = sample.values[feature] else {
          continue
        }
        timestamps.append(sample.timestamp)
        values.append(value)
      }

      // Z-score over the *full* history so each point's trailing 14-day
      // baseline is intact and causal, then window. Windowing first would
      // starve the earliest points of their baseline.
      var points = [DatedValue]()
      if baselineRelative {
        let zScores = CorrelationMath.rollingZScores(values: values, timestamps: timestamps)
        for index in zScores.indices {
          if let z = zScores[index] {
            points.append(DatedValue(date: timestamps[index], value: z))
          }
        }
      }
      else {
        points = zip(timestamps, values).map(DatedValue.init(date:value:))
      }

      if let latest = points.last?.date {
        let cutoff = latest.addingTimeInterval(-window)
        points = points.filter({ $0.date >= cutoff })
      }

      // Bin to daily means. HealthKit metrics are read over trailing windows
      // (resting HR looks back 48h), so consecutive rows repeat the same value
      // and a raw plot degenerates into long flat runs and step artifacts.
      let series = HeadacheManager.dailyMeans(of: points)

      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      return (series, episodes)
    }
  }

  /// Collapses dated values into one mean per calendar day, chronologically.
  ///
  /// - Parameter points: The dated values.
  /// - Returns: One value per day with data.
  static func dailyMeans(of points: [DatedValue]) -> [DatedValue] {
    var sums = [Date: (total: Double, count: Int)]()
    for point in points {
      let day = Calendar.current.startOfDay(for: point.date)
      let existing = sums[day] ?? (0.0, 0)
      sums[day] = (existing.total + point.value, existing.count + 1)
    }

    return sums
      .map({ DatedValue(date: $0.key, value: $0.value.total / Double($0.value.count)) })
      .sorted(by: { $0.date < $1.date })
  }

}

// MARK: - Data integrity

extension HeadacheManager {

  /// Repairs data integrity violations left behind by earlier versions:
  /// resolved flags that disagree with the open-severity invariant, multiple
  /// unresolved headaches, and missing identifiers.
  func repairDataIntegrity() async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
      let headaches = try context.fetch(request)

      var repairedCount = 0
      var unresolved = [Headache]()

      for headache in headaches {
        // Assign missing identifiers so edits can address the objects.
        if headache.identifier == nil {
          headache.identifier = UUID()
          repairedCount += 1
        }

        for severity in headache.severitiesArray where severity.identifier == nil {
          severity.identifier = UUID()
          repairedCount += 1
        }

        guard !headache.severitiesArray.isEmpty else {
          continue
        }

        // Reconcile the resolved flag with the open-severity invariant:
        // unresolved if and only if the last severity has no end time.
        let hasOpenSeverity = headache.severitiesArray.last?.endTime == nil
        if headache.resolved == hasOpenSeverity {
          headache.resolved = !hasOpenSeverity
          repairedCount += 1
        }

        if !headache.resolved {
          unresolved.append(headache)
        }
      }

      // At most one headache may be open; keep the newest and resolve the rest.
      if unresolved.count > 1 {
        for headache in unresolved.dropLast() {
          _ = headache.resolve(end: headache.pendingEndTime ?? Date())
          repairedCount += 1
        }
      }

      if repairedCount > 0 {
        logInfo("Repaired \(repairedCount) data integrity issues.")
      }
    }
  }

}

// MARK: - Caching

extension HeadacheManager {
  
  /// Updates the application's custom headache types.
  func updateCustomTypes() async throws {
    let types: [Headache.Types] = try await DataController.shared.performInBackground { context in
      let request = Headache.fetchRequest()
      let headaches = try context.fetch(request)
      return headaches.map({ $0.headacheType }).sorted()
    }
    
    let customTypes = types.filter({ !Headache.Types.definedCases.contains($0) })
    let uniqueCustomTypes = customTypes.unique()
    preferences.shared.customTypes = uniqueCustomTypes
  }
  
}

// MARK: - Getting headaches and severities

extension HeadacheManager {
  
  /// Gets the current headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the current headache to update it.
  ///   Errors thrown in this block will be received in completion.
  private func currentHeadache<T>(update: @escaping (Headache?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "resolved = NO")
      request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
      request.fetchLimit = 1
      return try update(try context.fetch(request).first, context)
    }
  }
  
  /// Gets the headache and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the headache to update it. Errors
  ///   thrown in this block will be received in completion.
  private func headacheWithIdentifier<T>(identifier: UUID, update: @escaping (Headache?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest(withIdentifier: identifier)
      return try update((try context.fetch(request)).first, context)
    }
  }
  
  /// Gets the severity and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameter update: Called with the severity to update it. Errors
  ///   thrown in this block will be received in completion.
  private func severityWithIdentifier<T>(identifier: UUID, update: @escaping (SeverityState?, NSManagedObjectContext) throws -> T) async throws -> T {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = SeverityState.fetchRequest(withIdentifier: identifier)
      return try update((try context.fetch(request)).first, context)
    }
  }
  
  /// Gets the sorted training data and calls it with the update block before
  /// saving the context and calling the completion block.
  ///
  /// - Parameters:
  ///   - predicate: The (optional) predicate to apply.
  ///   - fetchLimit: The limit of fetch results to return.
  ///   - ascending: Whether the returned list is ascending date order.
  ///   - update: Called with the training data to update it. Errors thrown in
  ///     this block will be received in completion.
  private func trainingData<T>(predicate: NSPredicate? = nil, fetchLimit: Int = 0, ascending: Bool = true, update: @escaping ([TrainingData], NSManagedObjectContext) throws -> T) async throws -> T {
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
      request.predicate = predicate
      request.fetchLimit = fetchLimit
      return try update(try context.fetch(request), context)
    }
  }
  
  /// The training-row counts broken down by derived outlook label.
  ///
  /// Labels are derived from headache intervals (not a stored field), so this
  /// walks every row and classifies it the same way training does: positives
  /// are rows within the rolling 24h window of an onset, negatives are clear
  /// rows, and in-headache rows are excluded from the classifier. Used by the
  /// debug screen.
  ///
  /// - Returns: The positive, negative, in-headache, and total row counts.
  func trainingDataOutlookCounts() async throws -> (positive: Int, negative: Int, inHeadache: Int, total: Int) {
    return try await trainingData { trainingData, context in
      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      trainingData.deriveLabels(from: episodes)

      var positive = 0, negative = 0, inHeadache = 0
      for row in trainingData {
        switch row.outlook {
        case .possibleHeadache: positive += 1
        case .noHeadache: negative += 1
        case .headache: inHeadache += 1
        case .none: break
        }
      }
      return (positive, negative, inHeadache, trainingData.count)
    }
  }

  /// Gets the date of the last training data sample.
  ///
  /// - Returns: A date.
  func lastTrainingDataDate() async throws -> Date? {
    return try await trainingData(fetchLimit: 1, ascending: false) { trainingData, _ in
      return trainingData.first?.timestamp
    }
  }
  
  /// Whether there is a current headache.
  func hasCurrentHeadache() async throws -> Bool {
    return try await currentHeadache { headache, _ in
      return headache != nil
    }
  }
  
  /// The identifier of the current headache.
  func currentHeadacheIdentifier() async throws -> UUID? {
    return try await currentHeadache { headache, _ in
      return headache?.identifier
    }
  }
  
  /// The identifier of the current headache's current severity identifier.
  func currentSeverityIdentifier() async throws -> UUID? {
    return try await currentHeadache { headache, _ in
      return headache?.severitiesArray.last?.identifier
    }
  }

  /// Merges duplicate tags (equal values) into one, re-pointing headaches.
  /// CloudKit imports from other devices can introduce duplicates because
  /// Tag has no unique constraint the mirror can enforce.
  func dedupeTags() async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let tags = try context.fetch(Tag.fetchRequest())
      var canonical = [String: Tag]()

      for tag in tags {
        guard let value = tag.value else {
          context.delete(tag)
          continue
        }

        if let keeper = canonical[value] {
          for headache in (tag.headaches as? Set<Headache>) ?? [] {
            headache.removeFromTags(tag)
            headache.addToTags(keeper)
          }
          context.delete(tag)
        }
        else {
          canonical[value] = tag
        }
      }
    }
  }

  /// Recomputes the shared current severity from the store and reloads the
  /// widgets. Called after remote changes, which bypass the local write
  /// paths that normally keep the shared defaults in sync.
  func refreshSharedState() async throws {
    let severity: Headache.Severity? = try await currentHeadache { headache, _ in
      return headache?.severity
    }
    preferences.shared.setCurrentSeverity(severity)
  }

  /// The start time of the current headache, if one is in progress.
  func currentHeadacheStart() async throws -> Date? {
    return try await currentHeadache { headache, _ in
      return headache?.startTime
    }
  }

  /// The end time of the most recently resolved headache, if any — the last
  /// severity interval's end on the newest resolved headache.
  func lastResolvedHeadacheEnd() async throws -> Date? {
    return try await DataController.shared.performInBackground { context in
      let request = Headache.fetchRequest()
      request.predicate = NSPredicate(format: "resolved = YES")
      // The most recent *end*, not the most recently *recorded* headache: a
      // back-logged old headache is created now but ended in the past, so
      // sorting by createdAt and taking the first would pick it and overstate
      // the headache-free streak. `endTime` is computed (the last severity's
      // end), so scan all resolved headaches; prefetch severities to avoid N+1.
      request.relationshipKeyPathsForPrefetching = ["severities"]
      return try context.fetch(request).compactMap({ $0.severitiesArray.last?.endTime }).max()
    }
  }

  /// Whole days a person has been headache-free, from the last resolved
  /// headache's end to now. Nil when there's never been a resolved headache.
  ///
  /// - Parameters:
  ///   - end: The last resolved headache's end time.
  ///   - now: The current time.
  /// - Returns: Whole days headache-free, or nil.
  static func daysHeadacheFree(since end: Date?, now: Date = Date()) -> Int? {
    guard let end = end, now > end else {
      return end == nil ? nil : 0
    }
    return Calendar.current.dateComponents([.day], from: end, to: now).day
  }

}

// MARK: Prediction

extension HeadacheManager {
  
  /// Resets all prediction and learning data.
  func resetPrediction() {
    predictor.reset()
  }
  
  /// Whether or not the application needs more training data.
  ///
  /// - Returns: A boolean indicating if the app should ask for more training data.
  func needsTrainingData() async throws -> Bool {
    guard let timestamp = try await lastTrainingDataDate() else {
      return true
    }
    
    return Date().timeIntervalSince(timestamp) > 3600.0 // Every 1 hour
  }
  
  /// Whether or not the device contains training data that's newer than
  /// the latest compiled models.
  ///
  /// - Returns: A boolean indicating if the app needs to train its models.
  func needsTraining() async throws -> Bool {
    guard let timestamp = try await lastTrainingDataDate() else {
      return false
    }

    guard let lastTrainingDate = predictor.modelUpdatedAt else {
      // No models have been trained yet. Bootstrap the first training run
      // once enough samples have accumulated.
      return try await trainingDataCount() >= Constants.minimumTrainingDataCount
    }

    return timestamp.timeIntervalSince(lastTrainingDate) > 0.0
  }

  /// The number of training data samples.
  ///
  /// - Returns: The count of training data.
  func trainingDataCount() async throws -> Int {
    return try await DataController.shared.performInBackground { context in
      return try context.count(for: TrainingData.fetchRequest())
    }
  }
  
  /// Cancels the current classification input reading.
  func cancelClassificationInput() {
    weatherManager.cancel()
    locationManager.cancel()
  }
  
  /// Creates a model input ready for prediction.
  ///
  /// - Parameters:
  ///   - date: The date of the predictor's desired input.
  ///   - inWidget: Whether this method is being called from within a widget.
  /// - Returns: Model input for the specified date.
  func predictorInput(atDate date: Date, inWidget: Bool) async -> ModelInput {
    // Get the location
    var location: CLLocation?
    do {
      location = try await locationManager.location()
    }
    catch {
      logError("Error getting location: \(error)")
    }
    
    // Get the weather
    var weather: Weather?
    if let location = location {
      do {
        weather = try await weatherManager.weather(at: date, for: location)
      }
      catch {
        logError("Error getting weather: \(error)")
      }
    }
    else {
      logWarning("Location was nil - not fetching weather.")
    }
    
    // Get the health kit data
    let healthKitData = healthKitManager.readHealthKitData(endingAt: date, inWidget: inWidget)

    // For baseline-relative slopes, read the baseline metrics as of ~6h
    // earlier so the model can see how far the autonomic signals are trending.
    // Gated on the feature; restricted to the non-derived baseline metrics so
    // this second read stays cheap (no full sweep, no heartbeat-series read).
    // Consequence: HRV-derived metrics get a z-score but no slope.
    var previousHealthKitData: [HealthKitData: Double]?
    if Preferences.Predictors().baselineRelative {
      let slopeMetrics = Set(BaselineFeatures.metrics.filter({ !$0.isDerived }))
      previousHealthKitData = healthKitManager.readHealthKitData(endingAt: date.addingTimeInterval(-BaselineFeatures.slopeGap), inWidget: inWidget, only: slopeMetrics)
    }

    // Trailing-window context from fixed clock windows: hourly HealthKit
    // buckets and the hourly weather points already fetched above. Cheap
    // enough to keep on the widget path (native aggregate queries only).
    var healthWindowStatistics: [HealthKitData: WindowStatistics]?
    var weatherWindowStatistics: [WeatherField: WindowStatistics]?
    if Preferences.Predictors().temporalContext {
      healthWindowStatistics = healthKitManager.readWindowStatistics(endingAt: date)
      if let windows = weather?.windowStatistics, !windows.isEmpty {
        weatherWindowStatistics = windows
      }
    }

    // Return the model input
    return ModelInput(
      date: date,
      location: location,
      weatherStatistics: weather?.statistics,
      healthKitData: healthKitData,
      previousHealthKitData: previousHealthKitData,
      healthWindowStatistics: healthWindowStatistics,
      weatherWindowStatistics: weatherWindowStatistics)
  }
  
  /// Gets classifier input appropriate for prediction, saves it as training
  /// data, runs a prediction, and evaluates the prediction.
  ///
  /// - Parameters:
  ///   - create: Whether (and as what) to record the input as a training row.
  ///   - predict: Runs a prediction before returning the input if true.
  ///   - inWidget: Whether this method is being called by a widget.
  func createPredict(create: CreatePolicy, predict: Bool = true, inWidget: Bool) async throws {
    let input = await predictorInput(atDate: Date(), inWidget: inWidget)

    switch create {
    case .never:
      break
    case .always(let source):
      try await createTrainingData(from: input, source: source)
    case .ifStale(let source, let maxAge):
      // A missing last row is stale too, so a fresh install seeds itself.
      let lastDate = try await lastTrainingDataDate() ?? .distantPast
      if Date().timeIntervalSince(lastDate) > maxAge {
        try await createTrainingData(from: input, source: source)
      }
    }

    if predict {
      // Score any matured forecasts before recording a new one.
      try await resolveEvaluations()

      let prediction = try await predictor.predict(input, inWidget: inWidget)

      // Only record forecasts a model actually made; before the first
      // training, predict returns the empty placeholder, and evaluating it
      // would inflate the accuracy readout with fabricated no-headache rows.
      if prediction != .empty {
        try await recordEvaluation(for: prediction)
      }
    }
  }

  /// When `createPredict` records a training row.
  enum CreatePolicy {

    /// Never; predict only.
    case never

    /// Always, tagged with the source.
    case always(TrainingDataSource)

    /// Only when the newest row is older than `maxAge` (or none exists).
    case ifStale(TrainingDataSource, maxAge: TimeInterval)

  }

  /// The window inside which a user-action row next to an existing row is
  /// dropped, so bursts of taps around a headache don't densify the series.
  static let trainingDataDedupeInterval: TimeInterval = 1800.0

  /// Creates new training data from the given input.
  ///
  /// Training labels are derived from headache intervals at training time,
  /// so no linkage to the triggering severity is kept. (The old provenance
  /// relationship crossed the Cloud/Local store boundary and was removed in
  /// model 2.1.)
  ///
  /// Rows are meant to sample time on a clock, not usage. Any source other
  /// than `.backdated` is skipped when a row already exists within
  /// `trainingDataDedupeInterval` of the input's date.
  ///
  /// - Parameters:
  ///   - input: The input data to create the training data from.
  ///   - source: What is creating the row.
  /// - Returns: Whether a row was created.
  @discardableResult
  func createTrainingData(from input: ModelInput, source: TrainingDataSource) async throws -> Bool {
    logInfo("Creating training data (\(source.title))...")
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      if source != .backdated, try TrainingData.rowExists(near: input.date, within: HeadacheManager.trainingDataDedupeInterval, in: context) {
        logDebug("Skipped training data: a row exists within \(Int(HeadacheManager.trainingDataDedupeInterval))s.")
        return false
      }

      let row = TrainingData(context: context, input: input)
      row.sourceKind = source
      logDebug("Created training data.")
      return true
    }
  }
  
  /// Upgrades the app's training data.
  ///
  /// Rows to upgrade are collected in a read pass, the replacement health and
  /// weather values are fetched outside of any managed object context, and a
  /// final write pass applies them. Blocking a context's queue while awaiting
  /// work on that same queue deadlocks, so no context is held while fetching.
  func upgradeTrainingData() async throws {
    // Activation can fire again while a pass is still running.
    guard !isUpgradingTrainingData else {
      logDebug("Training data upgrade already in progress.")
      return
    }
    isUpgradingTrainingData = true
    defer { isUpgradingTrainingData = false }

    logInfo("Upgrading health kit training data.")
    let healthUpgradeTargets: [(NSManagedObjectID, Date)] = try await trainingData(predicate: NSPredicate(format: "(healthData.version != %@) OR (healthData.version == %@)", Constants.trainingDataVersion as NSString, NSNull())) { trainingData, _ in
      return trainingData.compactMap { trainingDatum in
        guard let timestamp = trainingDatum.timestamp else {
          return nil
        }
        return (trainingDatum.objectID, timestamp)
      }
    }

    logInfo("Performing upgrade on \(healthUpgradeTargets.count) data.")
    var healthUpdates = [(NSManagedObjectID, [HealthKitData: Double], Date)]()
    for (objectID, timestamp) in healthUpgradeTargets {
      if let data = healthKitManager.readHealthKitData(endingAt: timestamp) {
        healthUpdates.append((objectID, data, timestamp))
      }
    }

    if !healthUpdates.isEmpty {
      try await DataController.shared.performInBackground(saveOnComplete: true) { context in
        for (objectID, data, timestamp) in healthUpdates {
          guard let trainingDatum = try? context.existingObject(with: objectID) as? TrainingData else {
            continue
          }
          trainingDatum.updateWithHealthKitData(data, at: timestamp)
        }
      }
    }
    logDebug("Finished upgrading health kit training data.")

    logInfo("Upgrading weather training data.")
    let weatherUpgradeTargets: [(NSManagedObjectID, Date)] = try await trainingData(predicate: NSPredicate(format: "(weatherData.version != %@) OR (weatherData.version == %@)", Constants.trainingDataWeatherVersion as NSString, NSNull())) { trainingData, _ in
      return trainingData.compactMap { trainingDatum in
        guard let timestamp = trainingDatum.timestamp else {
          return nil
        }
        return (trainingDatum.objectID, timestamp)
      }
    }

    logInfo("Performing weather upgrade on \(weatherUpgradeTargets.count) data.")
    var weatherUpdates = [(NSManagedObjectID, WeatherStatistics, Date)]()
    if !weatherUpgradeTargets.isEmpty {
      // Read the device's real location once and re-fetch every row's weather
      // for its original timestamp at that location. WeatherKit serves
      // historical weather, so this corrects past rows (e.g. any logged while
      // a simulated location was fed to the app) without touching the headache
      // record itself. Device-barometer readings are preserved (see
      // updateWithWeatherStatistics).
      do {
        let location = try await locationManager.location()
        for (objectID, timestamp) in weatherUpgradeTargets {
          do {
            let weather = try await weatherManager.weather(at: timestamp, for: location)
            weatherUpdates.append((objectID, weather.statistics, timestamp))
          }
          catch {
            logError("Error upgrading weather for \(timestamp): \(error)")
          }
        }
      }
      catch {
        logError("Error getting location for weather upgrade: \(error)")
      }
    }

    if !weatherUpdates.isEmpty {
      try await DataController.shared.performInBackground(saveOnComplete: true) { context in
        for (objectID, statistics, timestamp) in weatherUpdates {
          guard let trainingDatum = try? context.existingObject(with: objectID) as? TrainingData else {
            continue
          }
          trainingDatum.updateWithWeatherStatistics(statistics, at: timestamp)
        }
      }
    }
    logDebug("Finished upgrading weather training data.")

    try await backFillTrainingDataContext()
  }

  /// The number of training rows whose trailing-window context is missing or
  /// stale, for the debug screen.
  func trainingDataLackingContextCount() async throws -> Int {
    return try await DataController.shared.performInBackground { context in
      let request = TrainingData.fetchRequest()
      request.predicate = HeadacheManager.contextBackFillPredicate
      return try context.count(for: request)
    }
  }

  /// Rows whose context is missing or was computed with another version.
  private static var contextBackFillPredicate: NSPredicate {
    let version = Constants.trainingDataContextVersion as NSString
    return NSPredicate(format: "(contextData == nil) OR (contextData.healthVersion != %@) OR (contextData.healthVersion == %@) OR (contextData.weatherVersion != %@) OR (contextData.weatherVersion == %@)", version, NSNull(), version, NSNull())
  }

  /// The longest span read from HealthKit in one collection query.
  private static let contextBackFillChunk: TimeInterval = 31.0 * 86400.0

  /// The longest span requested from WeatherKit's hourly history at once.
  private static let weatherBackFillChunk: TimeInterval = 5.0 * 86400.0

  /// The number of rows written per save during the back-fill.
  private static let contextBackFillBatch = 200

  /// A row awaiting window context.
  private struct ContextBackFillTarget {
    let objectID: NSManagedObjectID
    let timestamp: Date
    let location: CLLocation?
    let needsHealth: Bool
    let needsWeather: Bool
  }

  /// Back-fills the trailing-window context of rows that lack it.
  ///
  /// HealthKit: one hourly collection query per window metric per ~month of
  /// history, merged into a sparse series and sliced per row — never a query
  /// per row. WeatherKit: rows are clustered by rounded location and calendar
  /// day, each cluster's hourly history is fetched in runs of a few days, and
  /// every row is sliced from that. A half whose read produced nothing keeps
  /// a nil version and is retried on the next activation, like `HealthData`.
  private func backFillTrainingDataContext() async throws {
    guard Preferences.Predictors().temporalContext else {
      return
    }

    let version = Constants.trainingDataContextVersion
    let targets: [ContextBackFillTarget] = try await trainingData(predicate: HeadacheManager.contextBackFillPredicate) { rows, _ in
      rows.compactMap { row in
        guard let timestamp = row.timestamp else {
          return nil
        }
        var location: CLLocation?
        if let stored = row.location, stored.timestamp != nil, stored.latitude != 0.0 || stored.longitude != 0.0 {
          location = CLLocation(latitude: stored.latitude, longitude: stored.longitude)
        }
        return ContextBackFillTarget(
          objectID: row.objectID,
          timestamp: timestamp,
          location: location,
          needsHealth: row.contextData?.healthVersion != version,
          needsWeather: row.contextData?.weatherVersion != version)
      }
    }

    guard !targets.isEmpty, let first = targets.first?.timestamp, let last = targets.last?.timestamp else {
      return
    }
    logInfo("Back-filling window context for \(targets.count) rows.")

    // MARK: HealthKit half

    var healthByRow = [NSManagedObjectID: [HealthKitData: WindowStatistics]]()
    let healthTargets = targets.filter({ $0.needsHealth })
    if !healthTargets.isEmpty {
      let windowSpan = TimeInterval(WindowStatisticsCalculator.bucketCount) * WindowStatisticsCalculator.bucketLength
      var seriesByMetric = [HealthKitData: [Date: Double]]()
      for metric in HealthKitData.windowMetrics where Preferences.Predictors().isCollectionEnabled(metric) {
        var merged = [Date: Double]()
        var chunkStart = first.addingTimeInterval(-windowSpan)
        while chunkStart < last {
          let chunkEnd = min(chunkStart.addingTimeInterval(HeadacheManager.contextBackFillChunk), last)
          if let series = healthKitManager.readHourlySeries(for: metric, in: DateInterval(start: chunkStart, end: chunkEnd)) {
            merged.merge(series, uniquingKeysWith: { _, new in new })
          }
          chunkStart = chunkEnd
        }
        if !merged.isEmpty {
          seriesByMetric[metric] = merged
        }
      }

      if !seriesByMetric.isEmpty {
        for target in healthTargets {
          var statistics = [HealthKitData: WindowStatistics]()
          for (metric, series) in seriesByMetric {
            guard let aggregate = metric.windowAggregate else {
              continue
            }
            let buckets = WindowStatisticsCalculator.buckets(from: series, endingAt: target.timestamp)
            if let value = WindowStatisticsCalculator.statistics(hourlyBuckets: buckets, aggregate: aggregate) {
              statistics[metric] = value
            }
          }
          healthByRow[target.objectID] = statistics
        }
      }
    }

    // MARK: WeatherKit half

    var weatherByRow = [NSManagedObjectID: [WeatherField: WindowStatistics]]()
    let weatherTargets = targets.filter({ $0.needsWeather })
    if !weatherTargets.isEmpty {
      var fallbackLocation: CLLocation?
      if weatherTargets.contains(where: { $0.location == nil }) {
        fallbackLocation = try? await locationManager.location()
      }

      // Cluster by rounded coordinate (~5 km) so one history fetch serves
      // every row logged around the same place.
      struct Cluster: Hashable {
        let latitude: Int
        let longitude: Int
      }
      var rowsByCluster = [Cluster: [(ContextBackFillTarget, CLLocation)]]()
      for target in weatherTargets {
        guard let location = target.location ?? fallbackLocation else {
          continue
        }
        let key = Cluster(latitude: Int((location.coordinate.latitude / 0.05).rounded()), longitude: Int((location.coordinate.longitude / 0.05).rounded()))
        rowsByCluster[key, default: []].append((target, location))
      }

      for (_, rows) in rowsByCluster {
        let sorted = rows.sorted(by: { $0.0.timestamp < $1.0.timestamp })
        guard let location = sorted.first?.1 else {
          continue
        }

        // Fetch runs of consecutive rows whose span fits one request.
        var index = 0
        while index < sorted.count {
          let runStart = sorted[index].0.timestamp
          var runEnd = index
          while runEnd + 1 < sorted.count && sorted[runEnd + 1].0.timestamp.timeIntervalSince(runStart) < HeadacheManager.weatherBackFillChunk {
            runEnd += 1
          }

          let run = sorted[index ... runEnd]
          let end = run[run.endIndex - 1].0.timestamp
          do {
            let weather = try await weatherManager.weather(at: end, for: location, trailing: end.timeIntervalSince(runStart))
            for (target, _) in run {
              let statistics = weather.windowStatistics(endingAt: target.timestamp)
              if !statistics.isEmpty {
                weatherByRow[target.objectID] = statistics
              }
            }
          }
          catch {
            logError("Error back-filling weather context ending \(end): \(error)")
          }
          index = runEnd + 1
        }
      }
    }

    // MARK: Write

    guard !healthByRow.isEmpty || !weatherByRow.isEmpty else {
      logInfo("Window context back-fill produced no data.")
      return
    }

    var batch = [ContextBackFillTarget]()
    for target in targets {
      batch.append(target)
      if batch.count == HeadacheManager.contextBackFillBatch {
        try await writeTrainingDataContext(for: batch, health: healthByRow, weather: weatherByRow)
        batch.removeAll()
      }
    }
    if !batch.isEmpty {
      try await writeTrainingDataContext(for: batch, health: healthByRow, weather: weatherByRow)
    }
    logInfo("Finished back-filling window context (\(healthByRow.count) health, \(weatherByRow.count) weather).")
  }

  /// Writes back-filled context for a batch of rows.
  private func writeTrainingDataContext(
    for batch: [ContextBackFillTarget],
    health: [NSManagedObjectID: [HealthKitData: WindowStatistics]],
    weather: [NSManagedObjectID: [WeatherField: WindowStatistics]]
  ) async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      for target in batch {
        guard let row = try? context.existingObject(with: target.objectID) as? TrainingData else {
          continue
        }
        if row.contextData == nil {
          row.contextData = ContextData(context: context)
        }
        if target.needsHealth, let statistics = health[target.objectID] {
          row.contextData?.updateWithHealthWindowStatistics(statistics, at: target.timestamp)
        }
        if target.needsWeather, let statistics = weather[target.objectID] {
          row.contextData?.updateWithWeatherWindowStatistics(statistics, at: target.timestamp)
        }
      }
    }
  }

  /// A snapshot of the location the app is actually reading right now, for
  /// diagnosing wrong-location weather. Reverse-geocodes the coordinate and
  /// fetches the live temperature there.
  struct LocationWeatherSnapshot {
    let coordinate: String
    let place: String
    let temperature: String
  }

  /// Reads the current location and the weather there, formatted for display.
  func locationWeatherSnapshot() async -> LocationWeatherSnapshot {
    let location: CLLocation
    do {
      location = try await locationManager.location()
    }
    catch {
      return LocationWeatherSnapshot(coordinate: "unavailable", place: "\(error)", temperature: "—")
    }

    let coordinate = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)

    var place = "Unknown"
    if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
      let parts = [placemark.locality, placemark.administrativeArea].compactMap { $0 }
      place = parts.isEmpty ? (placemark.country ?? "Unknown") : parts.joined(separator: ", ")
    }

    var temperature = "N/A"
    if let weather = try? await weatherManager.weather(at: Date(), for: location) {
      let celsius = weather.statistics.currentTemperature
      temperature = String(format: "%.1f°C / %.1f°F", celsius, celsius * 9.0 / 5.0 + 32.0)
    }

    return LocationWeatherSnapshot(coordinate: coordinate, place: place, temperature: temperature)
  }

  /// Re-fetches weather for *every* training row at the device's current
  /// location, regardless of version — the manual, user-triggered counterpart
  /// to `upgradeTrainingData`'s automatic pass. Use only after confirming the
  /// location snapshot is correct; otherwise it re-writes weather at the wrong
  /// place. Device-barometer readings are preserved (see
  /// `updateWithWeatherStatistics`).
  ///
  /// - Returns: The number of rows updated.
  func recomputeAllWeather() async throws -> (updated: Int, skippedNoLocation: Int) {
    // Each row remembers the coordinate it was logged at. Re-fetch its weather
    // *there* — so a row logged while travelling gets that city's weather, not
    // wherever the device is now. Rows with no stored location are left alone
    // (there's nothing to fetch against).
    let (targets, missing): ([(NSManagedObjectID, Date, CLLocation)], Int) = try await trainingData { rows, _ in
      var located = [(NSManagedObjectID, Date, CLLocation)]()
      var missing = 0
      for row in rows {
        guard let timestamp = row.timestamp else {
          continue
        }
        if let stored = row.location, stored.timestamp != nil, stored.latitude != 0.0 || stored.longitude != 0.0 {
          located.append((row.objectID, timestamp, CLLocation(latitude: stored.latitude, longitude: stored.longitude)))
        }
        else {
          missing += 1
        }
      }
      return (located, missing)
    }

    var updates = [(NSManagedObjectID, WeatherStatistics, Date)]()
    for (objectID, timestamp, location) in targets {
      if let weather = try? await weatherManager.weather(at: timestamp, for: location) {
        updates.append((objectID, weather.statistics, timestamp))
      }
    }

    if !updates.isEmpty {
      try await DataController.shared.performInBackground(saveOnComplete: true) { context in
        for (objectID, statistics, timestamp) in updates {
          guard let trainingDatum = try? context.existingObject(with: objectID) as? TrainingData else {
            continue
          }
          trainingDatum.updateWithWeatherStatistics(statistics, at: timestamp)
        }
      }
    }

    return (updates.count, missing)
  }
  
  /// Trains the classifiers.
  func trainClassifiers() async throws {
    // Build the training input inside the context block; the input holds
    // context-free data tables, so training itself runs outside of it.
    let input = try await trainingData(predicate: NSPredicate(format: "(healthData.version == %@) AND (weatherData.version == %@)", Constants.trainingDataVersion as NSString, Constants.trainingDataWeatherVersion as NSString)) { trainingData, context -> TrainingInput in
      // Derive labels from headache intervals rather than the severity
      // relationship, so edited and deleted headaches still label correctly.
      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      trainingData.deriveLabels(from: episodes)

      // Balancing happens inside TrainingInput on the binary risk label;
      // trimming by severity here would discard possible-headache positives.
      // The correlation samples ride along so training can run the engine
      // on each fold's prefix for personalization candidates.
      logDebug("Training classifiers with \(trainingData.count) data...")
      return try TrainingInput(
        trainingData: trainingData,
        correlationSamples: trainingData.compactMap({ $0.correlationSample }),
        episodes: episodes,
        enabledFeatures: Preferences.Predictors().enabledCorrelationFeatures())
    }

    try await predictor.train(input)

    // Refresh the correlation insights on the new data; a failure here
    // shouldn't fail training.
    do {
      try await computeInsights()
    }
    catch {
      logError("Error computing insights after training: \(error)")
    }
  }

  /// The episodes of every headache in the store.
  ///
  /// - Parameter context: The context to fetch in.
  /// - Returns: An array of headache episodes.
  static func headacheEpisodes(in context: NSManagedObjectContext) throws -> [HeadacheEpisode] {
    let request = Headache.fetchRequest()
    return try context.fetch(request)
      .compactMap({ $0.episode })
      .sorted(by: { $0.start < $1.start })
  }

  
  /// Records the prediction as a pending evaluation.
  ///
  /// An outlook forecast predicts the *future*, so it can't be scored
  /// against the present; the pending row matures after its window passes
  /// and `resolveEvaluations()` scores it against what actually happened.
  ///
  /// Forecasts are recorded from the app's foreground path and the hourly
  /// background refresh alike, so the prospective record isn't limited to
  /// the moments the app was opened (which cluster around headaches). A
  /// forecast within `evaluationDedupeInterval` of an existing one for the
  /// same horizon is not recorded again.
  ///
  /// - Parameter prediction: The prediction.
  func recordEvaluation(for prediction: RiskPrediction) async throws {
    // Only forecasts made outside a headache are evaluated; during a
    // headache the outlook trivially matches the present.
    guard try await !hasCurrentHeadache() else {
      return
    }

    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let now = Date()

      func record(probability: Double, window: TimeInterval, horizonHours: Int) {
        let request = Evaluation.fetchRequest()
        request.predicate = NSPredicate(format: "horizonHours == %@ AND timestamp >= %@", NSNumber(value: horizonHours), now.addingTimeInterval(-HeadacheManager.evaluationDedupeInterval) as NSDate)
        request.fetchLimit = 1
        if (try? context.count(for: request)) ?? 0 > 0 {
          return
        }

        let evaluation = Evaluation(context: context)
        evaluation.timestamp = now
        evaluation.horizonHours = Int64(horizonHours)
        evaluation.predictedProbability = probability
        evaluation.predictedOutlookRaw = probability >= RiskPrediction.RiskTier.evaluationPositiveThreshold
          ? Outlook.possibleHeadache.rawValue
          : Outlook.noHeadache.rawValue
        evaluation.resolveAfter = now.addingTimeInterval(window)
        evaluation.resolved = false
      }

      // The 24-hour forecast, plus the shorter horizon when it's available.
      record(probability: prediction.probability, window: [TrainingData].possibleHeadacheWindow, horizonHours: 24)
      if let shortProbability = prediction.shortProbability, shortProbability >= 0 {
        record(probability: shortProbability, window: RiskHorizon.short.window, horizonHours: Int(RiskHorizon.short.window / 3600.0))
      }
    }
  }

  /// The window inside which a second forecast for the same horizon is not
  /// recorded as a separate evaluation.
  static let evaluationDedupeInterval: TimeInterval = 1800.0

  /// Scores matured pending evaluations against the actual headache record.
  func resolveEvaluations() async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "(resolved == NO) AND (resolveAfter != nil) AND (resolveAfter <= %@)", Date() as NSDate)
      let pending = try context.fetch(request)

      guard !pending.isEmpty else {
        return
      }

      let episodes = try HeadacheManager.headacheEpisodes(in: context).sorted(by: { $0.start < $1.start })

      for evaluation in pending {
        guard let timestamp = evaluation.timestamp, let resolveAfter = evaluation.resolveAfter else {
          evaluation.resolved = true
          continue
        }

        // Did a headache actually start within the forecast window?
        let actualEpisode = episodes.first(where: { $0.start > timestamp && $0.start <= resolveAfter })
        let predictedPositive = evaluation.predictedOutlookRaw == Outlook.headache.rawValue || evaluation.predictedOutlookRaw == Outlook.possibleHeadache.rawValue

        evaluation.actualOutcome = actualEpisode != nil
        evaluation.outlook = predictedPositive == (actualEpisode != nil)
        evaluation.resolved = true
      }

      logInfo("Resolved \(pending.count) pending evaluations.")
    }
  }

  /// Calculates the observed forecast metrics over resolved evaluations.
  ///
  /// - Returns: The accuracy, the Brier score (nil when no probabilities
  ///   were recorded), and the resolved evaluation count.
  func evaluation(horizonHours: Int = 24) async throws -> (accuracy: Double, brier: Double?, count: Int) {
    return try await DataController.shared.performInBackground { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "resolved == YES AND horizonHours == %@", NSNumber(value: horizonHours))
      let evaluations = try context.fetch(request)

      guard evaluations.count > 0 else {
        return (0.0, nil, 0)
      }

      var successCount = 0
      var probabilities = [Double]()
      var outcomes = [Bool]()

      for evaluation in evaluations {
        successCount += evaluation.outlook ? 1 : 0

        // The stored outcome (reconstructed for rows resolved before it was
        // stored) pairs with the probability for the Brier score.
        if evaluation.predictedProbability >= 0, let outcome = evaluation.actualOutcome {
          probabilities.append(evaluation.predictedProbability)
          outcomes.append(outcome)
        }
      }

      let accuracy = Double(successCount) / Double(evaluations.count)
      let brier = PlattCalibration.brier(probabilities: probabilities, outcomes: outcomes)
      return (accuracy, brier, evaluations.count)
    }
  }
  
  /// The resolved forecasts for a horizon, oldest first, for the prospective
  /// accuracy record.
  ///
  /// - Parameter horizonHours: The horizon.
  /// - Returns: The resolved forecasts with a recorded probability.
  func evaluationSeries(horizonHours: Int = 24) async throws -> [EvaluationPoint] {
    return try await DataController.shared.performInBackground { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "resolved == YES AND horizonHours == %@ AND predictedProbability >= 0", NSNumber(value: horizonHours))
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      return try context.fetch(request).compactMap { evaluation in
        guard let timestamp = evaluation.timestamp, let outcome = evaluation.actualOutcome else {
          return nil
        }
        return EvaluationPoint(date: timestamp, probability: evaluation.predictedProbability, outcome: outcome)
      }
    }
  }

  /// Deletes all of the stored evaluations.
  func resetEvaluation() async throws {
    return try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Evaluation.fetchRequest()
      let evaluations = try context.fetch(request)

      for evaluation in evaluations {
        context.delete(evaluation)
      }
    }
  }

  /// A logged 24-hour risk forecast, for the "how your risk evolved" timeline.
  struct RiskHistoryPoint: Identifiable, Equatable {
    let date: Date
    let probability: Double
    var id: Date { date }
  }

  /// The 24-hour risk forecasts logged over the trailing window, oldest-first.
  /// Backward-looking (there are gaps while a headache is active, and the
  /// cadence follows background refreshes).
  ///
  /// - Parameter hours: How far back to look.
  /// - Returns: The logged forecasts in time order.
  func riskHistory(hours: Double = 48) async throws -> [RiskHistoryPoint] {
    // One query serves the app's Risk Trend card and every risk widget.
    return try await WidgetDataSource.riskHistory(hours: hours)
  }

}
