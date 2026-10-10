//
//  HeadacheManager+Recap.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import CoreData
import DataController
import Foundation

extension HeadacheManager {

  /// Builds the shareable monthly recap for the month containing `date`.
  ///
  /// - Parameters:
  ///   - date: Any date within the target month (defaults to now).
  ///   - calendar: The calendar to reckon the month in.
  /// - Returns: The distilled recap.
  func monthlyRecap(forMonthContaining date: Date = Date(), calendar: Calendar = .current) async throws -> MonthlyRecap {
    let now = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart.addingTimeInterval(31 * 86400)
    let monthInterval = DateInterval(start: monthStart, end: nextMonth)

    // Headache episodes overlapping the month; in-progress episodes clip to now.
    let episodes: [DateInterval] = try await DataController.shared.performInBackground { context in
      try HeadacheManager.headacheEpisodes(in: context).compactMap { episode -> DateInterval? in
        let end = max(episode.end ?? now, episode.start)
        guard end > episode.start else {
          return nil
        }
        let interval = DateInterval(start: episode.start, end: end)
        return interval.intersects(monthInterval) ? interval : nil
      }
    }

    // The strongest confident, non-confounded onset patterns.
    let report = InsightsStore.shared.load()
    let patterns = (report?.insights ?? [])
      .filter { $0.target == .occurrence && $0.confidence != .suggestive && $0.explainedBy == nil }
      .sorted { abs($0.coefficient) > abs($1.coefficient) }
      .map { $0.directionDescription }

    return MonthlyRecap.make(
      monthStart: monthStart,
      now: now,
      calendar: calendar,
      episodes: episodes,
      patterns: patterns)
  }

}
