//
//  MonthlyRecap.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import Foundation

/// A month's headache patterns, distilled into a shareable "Your Patterns"
/// recap. Pure aggregation over episodes and insights — no Core Data, so it's
/// unit-testable.
struct MonthlyRecap: Equatable {

  /// A week within the recap window and how many headaches began in it.
  struct WeekStat: Equatable {
    /// The 1-based week index within the month.
    let index: Int
    /// The number of headaches that began in the week.
    let onsets: Int
  }

  /// A display title for the month (e.g. "July 2026").
  let monthTitle: String

  /// The number of headaches that began in the window.
  let headacheCount: Int

  /// The number of observed days in the window (through today for the current
  /// month).
  let totalDays: Int

  /// The number of observed days with no headache.
  let headacheFreeDays: Int

  /// The longest run of consecutive headache-free days.
  let longestFreeStreak: Int

  /// The week with the fewest headache onsets, when there were any headaches.
  let bestWeek: WeekStat?

  /// The week with the most headache onsets, when there were any headaches.
  let worstWeek: WeekStat?

  /// The strongest personal patterns, as human-readable lines (from insights).
  let topPatterns: [String]

  /// Whether there's anything worth recapping.
  var hasData: Bool {
    return headacheCount > 0
  }

  // MARK: Building

  /// Builds a recap from raw month data.
  ///
  /// - Parameters:
  ///   - monthStart: The first instant of the month.
  ///   - now: The current date, bounding the current month's window.
  ///   - calendar: The calendar to reckon days/weeks in.
  ///   - episodes: Headache intervals overlapping the month (in-progress
  ///     episodes clipped to `now`).
  ///   - patterns: Precomputed insight lines, strongest first.
  static func make(
    monthStart: Date,
    now: Date,
    calendar: Calendar = .current,
    episodes: [DateInterval],
    patterns: [String]
  ) -> MonthlyRecap {
    let monthStartDay = calendar.startOfDay(for: monthStart)
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStartDay) ?? monthStartDay.addingTimeInterval(31 * 86400)

    // The window ends at the end of the month, or the end of today for the
    // current month — we don't count days that haven't happened yet.
    // `midnightAfter` is DST-safe: a flat +86,400s lands an hour into the next
    // day across a spring-forward transition, which would pull tomorrow (a
    // future day) into the observed window and inflate the day counts.
    let windowEnd = min(nextMonth, calendar.midnightAfter(now))

    // Enumerate the observed days.
    var days = [Date]()
    var cursor = monthStartDay
    while cursor < windowEnd {
      days.append(cursor)
      cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
    }

    // Per-day headache flag: any episode overlapping the day.
    var freeFlags = [Bool]()
    var headacheDays = 0
    for day in days {
      let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
      let dayInterval = DateInterval(start: day, end: dayEnd)
      let hit = episodes.contains { $0.intersects(dayInterval) }
      freeFlags.append(!hit)
      if hit { headacheDays += 1 }
    }

    // Longest consecutive headache-free run.
    var longest = 0
    var run = 0
    for free in freeFlags {
      run = free ? run + 1 : 0
      longest = max(longest, run)
    }

    // Headache onsets that fell inside the observed window.
    let onsets = episodes.map { $0.start }.filter { $0 >= monthStartDay && $0 < windowEnd }
    let headacheCount = onsets.count

    // Onsets per 7-day bucket from the month start.
    var weekOnsets = [Int]()
    var weekStart = monthStartDay
    while weekStart < windowEnd {
      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart.addingTimeInterval(7 * 86400)
      let count = onsets.filter { $0 >= weekStart && $0 < weekEnd }.count
      weekOnsets.append(count)
      weekStart = weekEnd
    }

    var bestWeek: WeekStat?
    var worstWeek: WeekStat?
    if headacheCount > 0, !weekOnsets.isEmpty {
      if let minIndex = weekOnsets.indices.min(by: { weekOnsets[$0] < weekOnsets[$1] }) {
        bestWeek = WeekStat(index: minIndex + 1, onsets: weekOnsets[minIndex])
      }
      if let maxIndex = weekOnsets.indices.max(by: { weekOnsets[$0] < weekOnsets[$1] }) {
        worstWeek = WeekStat(index: maxIndex + 1, onsets: weekOnsets[maxIndex])
      }
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "MMMM yyyy"

    return MonthlyRecap(
      monthTitle: formatter.string(from: monthStart),
      headacheCount: headacheCount,
      totalDays: days.count,
      headacheFreeDays: days.count - headacheDays,
      longestFreeStreak: longest,
      bestWeek: bestWeek,
      worstWeek: worstWeek,
      topPatterns: Array(patterns.prefix(3)))
  }

}
