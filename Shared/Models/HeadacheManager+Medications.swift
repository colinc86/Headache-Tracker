//
//  HeadacheManager+Medications.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import CoreData
import DataController
import Foundation

// MARK: - Medications

extension HeadacheManager {

  /// Adds a medication entry to the headache with the given identifier.
  ///
  /// The name is trimmed; if a prior entry exists with the same
  /// case-insensitive name, its exact casing is reused for consistency.
  ///
  /// - Parameters:
  ///   - name: The medication's name.
  ///   - takenAt: When the medication was taken.
  ///   - headacheIdentifier: The owning headache's identifier.
  func addMedication(name: String, takenAt: Date, headacheIdentifier: UUID) async throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw HeadacheError.missing
    }

    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Headache.fetchRequest(withIdentifier: headacheIdentifier)
      guard let headache = try context.fetch(request).first else {
        throw HeadacheError.missing
      }

      let canonicalName = HeadacheManager.canonicalMedicationName(for: trimmed, in: context)
      let entry = MedicationEntry(context: context, name: canonicalName, takenAt: takenAt)
      headache.addToMedications(entry)
    }
  }

  /// Updates the medication entry with the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The entry's identifier.
  ///   - name: The new name, or nil to leave unchanged.
  ///   - takenAt: The new taken-at date, or nil to leave unchanged.
  ///   - efficacy: The new efficacy, or nil to leave unchanged.
  func updateMedication(identifier: UUID, name: String? = nil, takenAt: Date? = nil, efficacy: MedicationEntry.Efficacy? = nil) async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = MedicationEntry.fetchRequest(withIdentifier: identifier)
      guard let entry = try context.fetch(request).first else {
        throw HeadacheError.missing
      }

      if let name = name {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          entry.name = trimmed
        }
      }
      if let takenAt = takenAt {
        entry.takenAt = takenAt
      }
      if let efficacy = efficacy {
        entry.efficacy = efficacy
      }
    }
  }

  /// Deletes the medication entry with the given identifier.
  ///
  /// - Parameter identifier: The entry's identifier.
  func deleteMedication(identifier: UUID) async throws {
    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = MedicationEntry.fetchRequest(withIdentifier: identifier)
      guard let entry = try context.fetch(request).first else {
        return
      }
      context.delete(entry)
    }
  }

  /// Recently used medication names for autocomplete: the most recently taken
  /// distinct names, most recent first.
  ///
  /// - Parameter limit: The maximum number of names.
  /// - Returns: Distinct medication names.
  func recentMedicationNames(limit: Int = 8) async throws -> [String] {
    return try await DataController.shared.performInBackground { context in
      let request = MedicationEntry.fetchRequest()
      request.sortDescriptors = [NSSortDescriptor(key: "takenAt", ascending: false)]
      let entries = try context.fetch(request)
      return HeadacheManager.rankedMedicationNames(from: entries, limit: limit)
    }
  }

  /// The distinct medication names in recency order (each name at its most
  /// recent use), taking the first `limit`.
  ///
  /// - Parameters:
  ///   - entries: Entries sorted most recent first.
  ///   - limit: The maximum number of names.
  /// - Returns: Distinct names.
  static func rankedMedicationNames(from entries: [MedicationEntry], limit: Int) -> [String] {
    var seen = Set<String>()
    var names = [String]()

    for entry in entries {
      guard let name = entry.name, !name.isEmpty else { continue }
      let key = name.lowercased()
      if !seen.contains(key) {
        seen.insert(key)
        names.append(name)
      }
      if names.count >= limit {
        break
      }
    }

    return names
  }

  /// The canonical casing for a medication name: the most recent prior
  /// entry's exact name when one matches case-insensitively.
  ///
  /// - Parameters:
  ///   - name: The trimmed candidate name.
  ///   - context: The context to search in.
  /// - Returns: The canonical name.
  static func canonicalMedicationName(for name: String, in context: NSManagedObjectContext) -> String {
    let request = MedicationEntry.fetchRequest()
    request.predicate = NSPredicate(format: "name =[c] %@", name)
    request.sortDescriptors = [NSSortDescriptor(key: "takenAt", ascending: false)]
    request.fetchLimit = 1
    return (try? context.fetch(request).first?.name) ?? name
  }

}
