//
//  HeadacheManager+Exposures.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import CoreData
import DataController
import Foundation

/// A value-type snapshot of a logged exposure.
struct ExposureSnapshot: Identifiable {

  /// The exposure's identifier.
  let id: UUID

  /// The exposure's kind raw value.
  let kind: String

  /// The exposure's timestamp.
  let timestamp: Date

}

// MARK: - Exposures

extension HeadacheManager {

  /// Sets the exposures logged on the given day, replacing that day's set.
  ///
  /// Rows are keyed by day: kinds absent from the set are deleted, missing
  /// ones are created at noon of the day (a representative time for
  /// trailing-window math), and duplicates (multi-device sync) collapse.
  ///
  /// - Parameters:
  ///   - kinds: The sanitized exposure kind raw values in effect for the day.
  ///   - day: Any date within the day being edited.
  func setExposures(_ kinds: Set<String>, on day: Date) async throws {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: day)
    let endOfDay = startOfDay.addingTimeInterval(86400.0)
    let noon = startOfDay.addingTimeInterval(12.0 * 3600.0)

    try await DataController.shared.performInBackground(saveOnComplete: true) { context in
      let request = Exposure.fetchRequest()
      request.predicate = NSPredicate(format: "(timestamp >= %@) AND (timestamp < %@)", startOfDay as NSDate, endOfDay as NSDate)
      let existing = try context.fetch(request)

      var seenKinds = Set<String>()
      for exposure in existing {
        guard let kind = exposure.kindRaw, kinds.contains(kind), !seenKinds.contains(kind) else {
          // Removed from the set, unkeyed, or a duplicate.
          context.delete(exposure)
          continue
        }
        seenKinds.insert(kind)
      }

      for kind in kinds.subtracting(seenKinds) {
        let exposure = Exposure(context: context)
        exposure.identifier = UUID()
        exposure.kindRaw = kind
        exposure.timestamp = noon
      }
    }
  }

  /// The exposures logged on the given day.
  ///
  /// - Parameter day: Any date within the day.
  /// - Returns: The day's exposures.
  func exposures(on day: Date) async throws -> [ExposureSnapshot] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: day)
    let endOfDay = startOfDay.addingTimeInterval(86400.0)

    return try await DataController.shared.performInBackground { context in
      let request = Exposure.fetchRequest()
      request.predicate = NSPredicate(format: "(timestamp >= %@) AND (timestamp < %@)", startOfDay as NSDate, endOfDay as NSDate)
      request.sortDescriptors = [NSSortDescriptor(key: "kindRaw", ascending: true)]
      return try context.fetch(request).compactMap { exposure in
        guard let identifier = exposure.identifier, let kind = exposure.kindRaw, let timestamp = exposure.timestamp else {
          return nil
        }
        return ExposureSnapshot(id: identifier, kind: kind, timestamp: timestamp)
      }
    }
  }

  /// Distinct exposure kinds ever logged, most frequent first. Used to
  /// suggest previously-used custom kinds.
  ///
  /// - Returns: Distinct kind raw values.
  func exposureKinds() async throws -> [String] {
    return try await DataController.shared.performInBackground { context in
      let request = Exposure.fetchRequest()
      let exposures = try context.fetch(request)

      var counts = [String: Int]()
      for exposure in exposures {
        guard let kind = exposure.kindRaw else { continue }
        counts[kind, default: 0] += 1
      }

      return counts.sorted(by: { $0.value > $1.value }).map({ $0.key })
    }
  }

  /// The total number of logged exposures, for insights staleness.
  ///
  /// - Returns: The count.
  func exposureCount() async throws -> Int {
    return try await DataController.shared.performInBackground { context in
      return try context.count(for: Exposure.fetchRequest())
    }
  }

}
