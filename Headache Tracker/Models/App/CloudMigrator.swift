//
//  CloudMigrator.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import CoreData
import DataController
import Foundation

/// Copies the user-data graph into the cloud store the first time the app
/// launches with sync enabled.
///
/// When the store splits, the original combined file becomes the Local
/// (device-only) store, so its user rows — headaches, severities, tags,
/// medications, exposures — are no longer visible to the coordinator (their
/// entities belong to the Cloud configuration). This migrator opens the old
/// file read-only with a throwaway coordinator, copies the graph into the
/// live cloud store, and stamps a flag so it runs exactly once.
struct CloudMigrator {

  /// A migration error.
  enum MigrationError: DescribableError {
    case model

    var description: String {
      switch self {
      case .model:
        return "Unable to load the managed object model for migration."
      }
    }
  }

  /// Runs the migration if sync is on and it hasn't run yet.
  static func migrateIfNeeded() async throws {
    var sync = Preferences.Sync()
    guard sync.enabled && !sync.didMigrateUserData else {
      return
    }

    let migrated = try await migrateUserData()
    sync.didMigrateUserData = true
    logInfo("Cloud migration complete: copied \(migrated) headaches into the cloud store.")
  }

  /// Copies headaches (with severities, tags, medications) and exposures
  /// from the old combined store into the cloud store.
  ///
  /// - Returns: The number of headaches copied.
  private static func migrateUserData() async throws -> Int {
    guard let storeDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
      return 0
    }

    let oldStoreURL = storeDirectory.appendingPathComponent(DataController.localStoreFileName)
    guard FileManager.default.fileExists(atPath: oldStoreURL.path) else {
      return 0
    }

    // Open the old combined file read-only with the full model (no
    // configuration, so the user entities' tables are visible).
    guard let model = NSManagedObjectModel.mergedModel(from: [Bundle.main]) else {
      throw MigrationError.model
    }

    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try coordinator.addPersistentStore(
      type: .sqlite,
      at: oldStoreURL,
      options: [NSReadOnlyPersistentStoreOption: true])

    let sourceContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    sourceContext.persistentStoreCoordinator = coordinator

    // Snapshot the graph as value types on the source context's queue.
    struct SeveritySnapshot {
      let identifier: UUID?
      let rawValue: Int64
      let startTime: Date?
      let endTime: Date?
    }
    struct MedicationSnapshot {
      let identifier: UUID?
      let name: String?
      let takenAt: Date?
      let efficacyRaw: Int64
    }
    struct HeadacheSnapshot {
      let identifier: UUID?
      let classification: String?
      let createdAt: Date?
      let isPrimary: Bool
      let type: String?
      let notes: String?
      let resolved: Bool
      let severities: [SeveritySnapshot]
      let medications: [MedicationSnapshot]
      let tags: [String]
    }
    struct ExposureSnapshot {
      let identifier: UUID?
      let kindRaw: String?
      let timestamp: Date?
      let amount: Double
      let notes: String?
    }

    let (headaches, exposures): ([HeadacheSnapshot], [ExposureSnapshot]) = try await sourceContext.perform {
      let headacheRequest = NSFetchRequest<NSManagedObject>(entityName: "Headache")
      let headaches = try sourceContext.fetch(headacheRequest).map { headache -> HeadacheSnapshot in
        let severities = ((headache.value(forKey: "severities") as? Set<NSManagedObject>) ?? []).map { severity in
          SeveritySnapshot(
            identifier: severity.value(forKey: "identifier") as? UUID,
            rawValue: severity.value(forKey: "rawValue") as? Int64 ?? 0,
            startTime: severity.value(forKey: "startTime") as? Date,
            endTime: severity.value(forKey: "endTime") as? Date)
        }
        let medications = ((headache.value(forKey: "medications") as? Set<NSManagedObject>) ?? []).map { entry in
          MedicationSnapshot(
            identifier: entry.value(forKey: "identifier") as? UUID,
            name: entry.value(forKey: "name") as? String,
            takenAt: entry.value(forKey: "takenAt") as? Date,
            efficacyRaw: entry.value(forKey: "efficacyRaw") as? Int64 ?? -1)
        }
        let tags = ((headache.value(forKey: "tags") as? Set<NSManagedObject>) ?? []).compactMap { tag in
          tag.value(forKey: "value") as? String
        }
        return HeadacheSnapshot(
          identifier: headache.value(forKey: "identifier") as? UUID,
          classification: headache.value(forKey: "classification") as? String,
          createdAt: headache.value(forKey: "createdAt") as? Date,
          isPrimary: headache.value(forKey: "isPrimary") as? Bool ?? true,
          type: headache.value(forKey: "type") as? String,
          notes: headache.value(forKey: "notes") as? String,
          resolved: headache.value(forKey: "resolved") as? Bool ?? true,
          severities: severities,
          medications: medications,
          tags: tags)
      }

      let exposureRequest = NSFetchRequest<NSManagedObject>(entityName: "Exposure")
      let exposures = try sourceContext.fetch(exposureRequest).map { exposure in
        ExposureSnapshot(
          identifier: exposure.value(forKey: "identifier") as? UUID,
          kindRaw: exposure.value(forKey: "kindRaw") as? String,
          timestamp: exposure.value(forKey: "timestamp") as? Date,
          amount: exposure.value(forKey: "amount") as? Double ?? 0.0,
          notes: exposure.value(forKey: "notes") as? String)
      }

      return (headaches, exposures)
    }

    // Rebuild the graph in the live cloud store; skip anything whose
    // identifier already exists (re-runs, or CloudKit already imported it
    // from another device).
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      var tagsByValue = [String: Tag]()
      for tag in try context.fetch(Tag.fetchRequest()) {
        if let value = tag.value {
          tagsByValue[value] = tag
        }
      }

      let existingHeadacheIdentifiers = Set(try context.fetch(Headache.fetchRequest()).compactMap({ $0.identifier }))
      for snapshot in headaches {
        if let identifier = snapshot.identifier, existingHeadacheIdentifiers.contains(identifier) {
          continue
        }

        let headache = Headache(context: context)
        headache.identifier = snapshot.identifier ?? UUID()
        headache.classification = snapshot.classification
        headache.createdAt = snapshot.createdAt
        headache.isPrimary = snapshot.isPrimary
        headache.type = snapshot.type
        headache.notes = snapshot.notes
        headache.resolved = snapshot.resolved

        for severitySnapshot in snapshot.severities {
          let severity = SeverityState(context: context)
          severity.identifier = severitySnapshot.identifier ?? UUID()
          severity.rawValue = severitySnapshot.rawValue
          severity.startTime = severitySnapshot.startTime
          severity.endTime = severitySnapshot.endTime
          headache.addToSeverities(severity)
        }

        for medicationSnapshot in snapshot.medications {
          let entry = MedicationEntry(context: context)
          entry.identifier = medicationSnapshot.identifier ?? UUID()
          entry.name = medicationSnapshot.name
          entry.takenAt = medicationSnapshot.takenAt
          entry.efficacyRaw = medicationSnapshot.efficacyRaw
          headache.addToMedications(entry)
        }

        for value in snapshot.tags {
          let tag: Tag
          if let existing = tagsByValue[value] {
            tag = existing
          }
          else {
            tag = Tag(context: context)
            tag.value = value
            tagsByValue[value] = tag
          }
          headache.addToTags(tag)
        }
      }

      let existingExposureIdentifiers = Set(try context.fetch(Exposure.fetchRequest()).compactMap({ $0.identifier }))
      for snapshot in exposures {
        if let identifier = snapshot.identifier, existingExposureIdentifiers.contains(identifier) {
          continue
        }

        let exposure = Exposure(context: context)
        exposure.identifier = snapshot.identifier ?? UUID()
        exposure.kindRaw = snapshot.kindRaw
        exposure.timestamp = snapshot.timestamp
        exposure.amount = snapshot.amount
        exposure.notes = snapshot.notes
      }
    }

    return headaches.count
  }

}
