//
//  ProfileAnalytics.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Foundation

/// The headache profile behind the Profile tab: when headaches start, how a
/// typical one unfolds, how often they come, and how long the quiet stretches
/// last. Pure aggregation over episodes, so it's unit-testable.
struct ProfileAnalytics: Equatable {

  /// The direction the headache rate is moving.
  enum Direction: String, Codable, Equatable {
    case rising
    case falling
    case steady
  }

  /// One point of a headache's severity curve, aligned at its onset.
  struct CurvePoint: Identifiable, Equatable {
    /// The curve the point belongs to (-1 for the median).
    let series: Int
    /// Hours since onset.
    let hours: Double
    /// The severity's ordering value (0 none … 4 severe).
    let severity: Double

    var id: String {
      return "\(series)-\(hours)"
    }
  }

  /// How far back the profile looks.
  let windowDays: Int

  /// The headaches that began in the window.
  let headacheCount: Int

  /// The headaches per month over the window.
  let ratePerMonth: Double

  /// Whether the second half of the window had more or fewer headaches.
  let direction: Direction

  /// Onset counts by weekday (0 = Sunday) and hour.
  let rhythm: [[Int]]

  /// The start hour of the busiest three-hour onset window.
  let typicalOnsetHour: Int?

  /// The weekday (0 = Sunday) with clearly the most onsets.
  let peakWeekday: Int?

  /// The median length of resolved headaches.
  let medianDuration: TimeInterval?

  /// The most common peak severity.
  let commonPeak: Headache.Severity?

  /// The longest run of headache-free days in the window.
  let longestFreeStreak: Int

  /// Every headache's severity curve, aligned at onset, as step points.
  let curves: [CurvePoint]

  /// The median severity across headaches at each moment since onset.
  let medianCurve: [CurvePoint]

  /// How many hours the aligned curves span.
  let curveHours: Double

  /// The longest a curve is drawn.
  static let maximumCurveHours = 12.0

  /// The sampling step of the median curve, in hours.
  static let medianStep = 0.25

  // MARK: Building

  /// Builds the profile.
  ///
  /// - Parameters:
  ///   - episodes: Every headache episode, any order.
  ///   - now: The reference moment.
  ///   - calendar: The calendar to reckon days and hours in.
  ///   - windowDays: How far back to look.
  /// - Returns: The profile.
  static func make(episodes: [HeadacheEpisode], now: Date, calendar: Calendar = .current, windowDays: Int = 90) -> ProfileAnalytics {
    let today = calendar.startOfDay(for: now)
    let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today.addingTimeInterval(-Double(windowDays - 1) * 86400.0)
    let inWindow = episodes.filter({ $0.start >= windowStart && $0.start <= now }).sorted(by: { $0.start < $1.start })

    // Rhythm: onsets by weekday and hour.
    var rhythm = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    for episode in inWindow {
      let weekday = calendar.component(.weekday, from: episode.start) - 1
      let hour = calendar.component(.hour, from: episode.start)
      rhythm[weekday][hour] += 1
    }

    // The busiest three-hour window (wrapping past midnight).
    let byHour = (0 ..< 24).map { hour in rhythm.reduce(0, { $0 + $1[hour] }) }
    var typicalOnsetHour: Int?
    if !inWindow.isEmpty {
      let windows = (0 ..< 24).map { start in (0 ..< 3).reduce(0, { $0 + byHour[(start + $1) % 24] }) }
      if let best = windows.indices.max(by: { windows[$0] < windows[$1] }), windows[best] > 0 {
        typicalOnsetHour = best
      }
    }

    // A peak weekday only when it clearly leads.
    let byWeekday = rhythm.map({ $0.reduce(0, +) })
    var peakWeekday: Int?
    if let best = byWeekday.indices.max(by: { byWeekday[$0] < byWeekday[$1] }),
       byWeekday[best] >= 2,
       byWeekday.filter({ $0 == byWeekday[best] }).count == 1 {
      peakWeekday = best
    }

    // Rate and direction: first half of the window against the second.
    let months = Double(windowDays) / 30.44
    let ratePerMonth = months > 0 ? Double(inWindow.count) / months : 0.0
    let midpoint = windowStart.addingTimeInterval(now.timeIntervalSince(windowStart) / 2.0)
    let firstHalf = inWindow.filter({ $0.start < midpoint }).count
    let secondHalf = inWindow.count - firstHalf
    let direction: Direction
    if secondHalf - firstHalf >= 2 && Double(secondHalf) > Double(firstHalf) * 1.2 {
      direction = .rising
    }
    else if firstHalf - secondHalf >= 2 && Double(firstHalf) > Double(secondHalf) * 1.2 {
      direction = .falling
    }
    else {
      direction = .steady
    }

    // Typical length and peak.
    let durations = inWindow.compactMap({ episode in episode.end.map({ $0.timeIntervalSince(episode.start) }) }).sorted()
    let medianDuration = FeatureMedians.median(of: durations)
    let peaks = inWindow.compactMap(peakSeverity(of:))
    let peakCounts = Dictionary(grouping: peaks, by: { $0.orderingValue }).mapValues({ $0.count })
    let commonPeak = peakCounts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key < $1.key }).flatMap({ Headache.Severity(orderingValue: $0.key) })

    // The longest headache-free stretch.
    let intervals = inWindow.map({ DateInterval(start: $0.start, end: max($0.end ?? now, $0.start)) })
    var longest = 0
    var run = 0
    var day = windowStart
    while day <= today {
      let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400.0)
      let dayInterval = DateInterval(start: day, end: next)
      let hit = intervals.contains(where: { $0.intersects(dayInterval) })
      run = hit ? 0 : run + 1
      longest = max(longest, run)
      day = next
    }

    // Aligned curves and their median.
    let curveEpisodes = inWindow.filter({ !$0.severities.isEmpty })
    var curves = [CurvePoint]()
    var curveHours = 0.0
    for (index, episode) in curveEpisodes.enumerated() {
      let points = alignedSteps(of: episode, now: now)
      curveHours = max(curveHours, points.last?.hours ?? 0.0)
      curves.append(contentsOf: points.map({ CurvePoint(series: index, hours: $0.hours, severity: $0.severity) }))
    }
    curveHours = min(max(curveHours, 1.0), maximumCurveHours)

    var medianCurve = [CurvePoint]()
    if !curveEpisodes.isEmpty {
      var hours = 0.0
      while hours <= curveHours + 1e-9 {
        let values = curveEpisodes.map({ severity(of: $0, atHours: hours, now: now) })
        medianCurve.append(CurvePoint(series: -1, hours: hours, severity: FeatureMedians.median(of: values) ?? 0.0))
        hours += medianStep
      }
    }

    return ProfileAnalytics(
      windowDays: windowDays,
      headacheCount: inWindow.count,
      ratePerMonth: ratePerMonth,
      direction: direction,
      rhythm: rhythm,
      typicalOnsetHour: typicalOnsetHour,
      peakWeekday: peakWeekday,
      medianDuration: medianDuration,
      commonPeak: commonPeak,
      longestFreeStreak: longest,
      curves: curves,
      medianCurve: medianCurve,
      curveHours: curveHours)
  }

  // MARK: Helpers

  /// An episode's highest severity.
  static func peakSeverity(of episode: HeadacheEpisode) -> Headache.Severity? {
    return episode.severities.map({ $0.severity }).max(by: { $0.orderingValue < $1.orderingValue })
  }

  /// The severity an episode had a given number of hours after onset (0 once
  /// it ended).
  static func severity(of episode: HeadacheEpisode, atHours hours: Double, now: Date) -> Double {
    let moment = episode.start.addingTimeInterval(hours * 3600.0)
    if let end = episode.end, moment >= end {
      return 0.0
    }
    if episode.end == nil, moment > now {
      return 0.0
    }
    let current = episode.severities.last(where: { $0.start <= moment })
    return Double(max(current?.severity.orderingValue ?? 0, 0))
  }

  /// An episode's severity as step points, capped at the maximum curve span.
  static func alignedSteps(of episode: HeadacheEpisode, now: Date) -> [(hours: Double, severity: Double)] {
    let end = episode.end ?? now
    let span = min(max(end.timeIntervalSince(episode.start) / 3600.0, 0.0), maximumCurveHours)
    var points = [(hours: Double, severity: Double)]()
    for interval in episode.severities.sorted(by: { $0.start < $1.start }) {
      let hours = min(max(interval.start.timeIntervalSince(episode.start) / 3600.0, 0.0), span)
      let value = Double(max(interval.severity.orderingValue, 0))
      if let last = points.last {
        // A step: hold the previous value until this one begins.
        points.append((hours, last.severity))
      }
      points.append((hours, value))
    }
    if let last = points.last {
      points.append((span, last.severity))
      points.append((span, 0.0))
    }
    return points
  }

  // MARK: Text

  /// The busiest three-hour window as clock text: "9 PM–12 AM".
  var typicalOnsetText: String? {
    return typicalOnsetHour.map({ ProfileAnalytics.hourText($0) + "–" + ProfileAnalytics.hourText(($0 + 3) % 24) })
  }

  /// The peak weekday's name, plural: "Mondays".
  func peakWeekdayText(calendar: Calendar = .current) -> String? {
    return peakWeekday.map({ calendar.weekdaySymbols[$0] + "s" })
  }

  /// An hour as clock text: "9 PM".
  static func hourText(_ hour: Int) -> String {
    switch hour {
    case 0: return "12 AM"
    case 12: return "12 PM"
    case 1 ..< 12: return "\(hour) AM"
    default: return "\(hour - 12) PM"
    }
  }

}

/// The last two weeks at a glance for the Track tab's Today card: one dot per
/// day tinted by that day's worst headache, the current headache-free run, and
/// the longest run on record. Pure.
struct StreakSummary: Equatable {

  /// One day on the strip.
  struct Day: Identifiable, Equatable {
    let date: Date
    let peak: Headache.Severity?
    let isToday: Bool

    var id: Date {
      return date
    }
  }

  /// The days on the strip, oldest first.
  let days: [Day]

  /// Whole days since the last headache ended (0 during one, nil before any).
  let currentFreeDays: Int?

  /// The longest headache-free run on record, in days.
  let longestFreeStreak: Int

  /// Builds the summary.
  ///
  /// - Parameters:
  ///   - episodes: Every headache episode.
  ///   - now: The reference moment.
  ///   - calendar: The calendar to reckon days in.
  ///   - dayCount: How many days the strip shows.
  /// - Returns: The summary.
  static func make(episodes: [HeadacheEpisode], now: Date, calendar: Calendar = .current, dayCount: Int = 14) -> StreakSummary {
    let today = calendar.startOfDay(for: now)
    let sorted = episodes.sorted(by: { $0.start < $1.start })

    func interval(_ episode: HeadacheEpisode) -> DateInterval {
      return DateInterval(start: episode.start, end: max(episode.end ?? now, episode.start))
    }

    func peak(on day: Date) -> Headache.Severity? {
      let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400.0)
      let dayInterval = DateInterval(start: day, end: next)
      return sorted
        .filter({ interval($0).intersects(dayInterval) && $0.start < next })
        .compactMap(ProfileAnalytics.peakSeverity(of:))
        .max(by: { $0.orderingValue < $1.orderingValue })
    }

    let days = (0 ..< dayCount).reversed().compactMap { offset -> Day? in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
        return nil
      }
      return Day(date: date, peak: peak(on: date), isToday: offset == 0)
    }

    // The current run.
    var currentFreeDays: Int?
    if sorted.contains(where: { $0.end == nil }) {
      currentFreeDays = 0
    }
    else if let lastEnd = sorted.compactMap({ $0.end }).max() {
      currentFreeDays = HeadacheManager.daysHeadacheFree(since: lastEnd, now: now)
    }

    // The longest run on record, from the first headache to today.
    var longest = 0
    if let first = sorted.first {
      var run = 0
      var day = calendar.startOfDay(for: first.start)
      while day <= today {
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400.0)
        let dayInterval = DateInterval(start: day, end: next)
        let hit = sorted.contains(where: { interval($0).intersects(dayInterval) && $0.start < next })
        run = hit ? 0 : run + 1
        longest = max(longest, run)
        day = next
      }
    }

    return StreakSummary(days: days, currentFreeDays: currentFreeDays, longestFreeStreak: max(longest, currentFreeDays ?? 0))
  }

}
