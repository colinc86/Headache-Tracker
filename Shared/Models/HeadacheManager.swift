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
  
  /// The manager's location manager.
  let locationManager = LocationManager()
  
  /// Whether a widget is authorized for location updates.
  var authorizedForWidgetUpdates: Bool {
    return locationManager.authorizedForWidgetUpdates
  }
  
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
    try await createPredict(inWidget: false)
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
    try await createPredict(inWidget: false)
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

    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      // Only one headache may be open at a time.
      if end == nil {
        let request = Headache.fetchRequest()
        request.predicate = NSPredicate(format: "resolved = NO")
        request.fetchLimit = 1
        if try context.fetch(request).first != nil {
          throw HeadacheError.alreadyActive
        }
      }

      _ = Headache(context: context, severity: severity, classification: classification, type: type, start: start, end: end)
    }
    
    // Create the training data
    let input = await predictorInput(atDate: start, inWidget: false)
    try await createTrainingData(from: input)
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
      try await createTrainingData(from: input)
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
    let (samples, episodes, exposures, totalRowCount) = try await DataController.shared.performInBackground { context -> ([CorrelationSample], [HeadacheEpisode], [ExposureEvent], Int) in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      let trainingData = try context.fetch(request)
      let samples = trainingData.compactMap({ $0.correlationSample })
      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      let exposures = try HeadacheManager.exposureEvents(in: context)
      return (samples, episodes, exposures, trainingData.count)
    }

    logInfo("Computing insights from \(samples.count) samples, \(exposures.count) exposures, and \(episodes.count) episodes.")
    let engine = CorrelationEngine(samples: CorrelationEngine.merged(samples, exposures: exposures), episodes: episodes)
    let computed = engine.computeReport()

    // Store the total counts — the same numbers insights() compares against
    // for staleness. Using the filtered sample count instead made the cache
    // permanently stale when any row lacked usable values.
    let report = InsightsReport(
      generatedAt: computed.generatedAt,
      rowCount: totalRowCount,
      exposureCount: exposures.count,
      insights: computed.insights,
      insufficient: computed.insufficient,
      baselines: computed.baselines,
      schemaVersion: computed.schemaVersion)
    InsightsStore.shared.save(report)
    return report
  }

  /// The latest insights report, recomputing when stale.
  ///
  /// - Returns: The report.
  func insights() async throws -> InsightsReport {
    let rowCount = try await trainingDataCount()
    let exposureCount = try await exposureCount()
    if InsightsStore.shared.isStale(rowCount: rowCount, exposureCount: exposureCount) {
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
  func featureSeries(for feature: CorrelationFeature) async throws -> ([DatedValue], [HeadacheEpisode]) {
    return try await DataController.shared.performInBackground { context in
      let request = TrainingData.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
      let trainingData = try context.fetch(request)

      let samples = trainingData.compactMap({ $0.correlationSample })
      let exposures = try HeadacheManager.exposureEvents(in: context)
      let merged = CorrelationEngine.merged(samples, exposures: exposures)

      let series: [DatedValue] = merged.compactMap { sample in
        guard let value = sample.values[feature] else {
          return nil
        }
        return DatedValue(date: sample.timestamp, value: value)
      }

      let episodes = try HeadacheManager.headacheEpisodes(in: context)
      return (series, episodes)
    }
  }

  /// The events of every logged exposure in the store.
  ///
  /// - Parameter context: The context to fetch in.
  /// - Returns: An array of exposure events.
  static func exposureEvents(in context: NSManagedObjectContext) throws -> [ExposureEvent] {
    let request = Exposure.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
    return try context.fetch(request).compactMap { exposure in
      guard let kind = exposure.kindRaw, let timestamp = exposure.timestamp else {
        return nil
      }
      return ExposureEvent(kind: kind, timestamp: timestamp, amount: exposure.amount > 0 ? exposure.amount : nil)
    }
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
    return try await trainingData { trainingData, _ in
      return trainingData.count
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
    
    // Return the model input
    return ModelInput(date: date, location: location, weatherStatistics: weather?.statistics, healthKitData: healthKitData)
  }
  
  /// Gets classifier input appropriate for prediction, saves it as training
  /// data, runs a prediction, and evaluates the prediction.
  ///
  /// - Parameters:
  ///   - create: Set to true if the headache manager should create training
  ///     data with the prediction.
  ///   - predict: Runs a prediction before returning the input if true.
  ///   - inWidget: Whether this method is being called by a widget.
  func createPredict(create: Bool = true, predict: Bool = true, inWidget: Bool) async throws {
    let input = await predictorInput(atDate: Date(), inWidget: inWidget)
    
    if create {
      let identifier = try await currentSeverityIdentifier()
      try await createTrainingData(from: input)
    }
    
    if predict {
      // Score any matured forecasts before recording a new one.
      try await resolveEvaluations()

      let prediction = try await predictor.predict(input, inWidget: inWidget)

      // Only record forecasts a model actually made; before the first
      // training, predict returns the empty placeholder, and evaluating it
      // would inflate the accuracy readout with fabricated no-headache rows.
      if prediction != .empty {
        try await evaluatePrediction(prediction)
      }
    }
  }
  
  /// Creates new training data from the given input.
  ///
  /// Training labels are derived from headache intervals at training time,
  /// so no linkage to the triggering severity is kept. (The old provenance
  /// relationship crossed the Cloud/Local store boundary and was removed in
  /// model 2.1.)
  ///
  /// - Parameter input: The input data to create the training data from.
  func createTrainingData(from input: ModelInput) async throws {
    logInfo("Creating training data...")
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      _ = TrainingData(context: context, input: input)
      logDebug("Created training data.")
    }
  }
  
  /// Upgrades the app's training data.
  ///
  /// Rows to upgrade are collected in a read pass, the replacement health and
  /// weather values are fetched outside of any managed object context, and a
  /// final write pass applies them. Blocking a context's queue while awaiting
  /// work on that same queue deadlocks, so no context is held while fetching.
  func upgradeTrainingData() async throws {
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
    for (objectID, timestamp) in weatherUpgradeTargets {
      do {
        let location = try await locationManager.location()
        let weather = try await weatherManager.weather(at: timestamp, for: location)
        weatherUpdates.append((objectID, weather.statistics, timestamp))
      }
      catch {
        logError("Error upgrading weather: \(error)")
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
      logDebug("Training classifiers with \(trainingData.count) data...")
      return try TrainingInput(trainingData: trainingData)
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
    return try context.fetch(request).compactMap({ $0.episode })
  }

  
  /// Records the prediction as a pending evaluation.
  ///
  /// An outlook forecast predicts the *future*, so it can't be scored
  /// against the present; the pending row matures after its window passes
  /// and `resolveEvaluations()` scores it against what actually happened.
  ///
  /// - Parameter prediction: The prediction.
  private func evaluatePrediction(_ prediction: RiskPrediction) async throws {
    // Only forecasts made outside a headache are evaluated; during a
    // headache the outlook trivially matches the present.
    guard try await !hasCurrentHeadache() else {
      return
    }

    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let evaluation = Evaluation(context: context)
      evaluation.timestamp = Date()
      evaluation.predictedProbability = prediction.probability
      evaluation.predictedOutlookRaw = prediction.probability >= RiskPrediction.RiskTier.evaluationPositiveThreshold
        ? Outlook.possibleHeadache.rawValue
        : Outlook.noHeadache.rawValue
      evaluation.resolveAfter = Date().addingTimeInterval([TrainingData].possibleHeadacheWindow)
      evaluation.resolved = false
    }
  }

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
  func evaluation() async throws -> (accuracy: Double, brier: Double?, count: Int) {
    return try await DataController.shared.performInBackground { context in
      let request = Evaluation.fetchRequest()
      request.predicate = NSPredicate(format: "resolved == YES")
      let evaluations = try context.fetch(request)

      guard evaluations.count > 0 else {
        return (0.0, nil, 0)
      }

      var successCount = 0
      var probabilities = [Double]()
      var outcomes = [Bool]()

      for evaluation in evaluations {
        successCount += evaluation.outlook ? 1 : 0

        // The recorded probability plus whether the forecast was correct
        // reconstructs the actual outcome for the Brier score.
        if evaluation.predictedProbability >= 0 {
          let predictedPositive = evaluation.predictedProbability >= RiskPrediction.RiskTier.evaluationPositiveThreshold
          let actualPositive = evaluation.outlook ? predictedPositive : !predictedPositive
          probabilities.append(evaluation.predictedProbability)
          outcomes.append(actualPositive)
        }
      }

      let accuracy = Double(successCount) / Double(evaluations.count)
      let brier = PlattCalibration.brier(probabilities: probabilities, outcomes: outcomes)
      return (accuracy, brier, evaluations.count)
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
  
}
