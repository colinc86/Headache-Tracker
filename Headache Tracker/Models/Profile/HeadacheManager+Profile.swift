//
//  HeadacheManager+Profile.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import CoreData
import DataController
import Foundation

/// Everything the Track and Profile tabs read from the store in one pass.
struct ProfileSource {

  /// Every headache episode, oldest first.
  let episodes: [HeadacheEpisode]

  /// Medication use and ratings within the window, most used first.
  let medications: [ClinicianReportData.MedicationSummary]

}

extension HeadacheManager {

  /// Reads the episodes and medication summaries behind the profile.
  ///
  /// - Parameter windowDays: How far back medications are summarized.
  /// - Returns: The source.
  func profileSource(windowDays: Int = 90) async throws -> ProfileSource {
    let start = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date().addingTimeInterval(-Double(windowDays) * 86400.0)
    return try await DataController.shared.performInBackground(saveOnComplete: false) { context in
      let episodes = try HeadacheManager.headacheEpisodes(in: context)

      let request = MedicationEntry.fetchRequest()
      request.predicate = NSPredicate(format: "takenAt >= %@", start as NSDate)
      var byName = [String: (name: String, count: Int, helpful: Int, rated: Int)]()
      for entry in try context.fetch(request) {
        guard let name = entry.name else {
          continue
        }
        var summary = byName[name.lowercased()] ?? (name, 0, 0, 0)
        summary.count += 1
        if entry.efficacy != .unrated {
          summary.rated += 1
          if entry.efficacy == .helpful || entry.efficacy == .somewhatHelpful {
            summary.helpful += 1
          }
        }
        byName[name.lowercased()] = summary
      }

      let medications = byName.values
        .map({ ClinicianReportData.MedicationSummary(name: $0.name, count: $0.count, helpfulCount: $0.helpful, ratedCount: $0.rated) })
        .sorted(by: { $0.count != $1.count ? $0.count > $1.count : $0.name.lowercased() < $1.name.lowercased() })

      return ProfileSource(episodes: episodes, medications: medications)
    }
  }

}
