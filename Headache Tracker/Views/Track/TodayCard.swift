//
//  TodayCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// The Track tab's "Today" card: the current headache-free run as a ring
/// against the longest on record, the last two weeks as a strip of dots tinted
/// by each day's worst headache, and at most one line of news (a model
/// milestone or what changed since the last visit).
struct TodayCard: View {

  /// The streak summary.
  let streak: StreakSummary

  /// One line of news, when there is one.
  let news: String?

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var current: Int {
    return streak.currentFreeDays ?? 0
  }

  var body: some View {
    Card(title: "Today", systemImage: "sun.max.fill", foregroundColor: colorTheme.teal) {
      VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
        HStack(alignment: .center, spacing: Tokens.Spacing.lg) {
          streakRing
          VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(headline)
              .font(.subheadline.weight(.semibold))
              .fixedSize(horizontal: false, vertical: true)
            dayStrip
          }
        }

        if let news = news {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
            Image(systemName: "sparkle")
              .foregroundColor(colorTheme.teal)
            Text(news)
              .font(.footnote)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  private var headline: String {
    guard streak.currentFreeDays != nil else {
      return "No headaches logged yet."
    }
    if current == 0 {
      return "A headache in the last day."
    }
    if current >= streak.longestFreeStreak, current > 1 {
      return "\(current) days headache-free, your longest run yet."
    }
    return "\(current) \(current == 1 ? "day" : "days") headache-free. Your best is \(streak.longestFreeStreak)."
  }

  /// The current run against the longest one.
  private var streakRing: some View {
    let fraction = streak.longestFreeStreak > 0 ? Double(current) / Double(streak.longestFreeStreak) : 0.0
    return RiskRing(probability: min(fraction, 1.0), tint: colorTheme.teal, lineWidth: 7, trackOpacity: 0.18) {
      VStack(spacing: -2) {
        Text("\(current)")
          .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
        Text(current == 1 ? "day" : "days")
          .font(.caption2.weight(.semibold))
          .foregroundColor(.secondary)
      }
    }
    .frame(width: 72, height: 72)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(current) days headache-free, longest run \(streak.longestFreeStreak) days")
  }

  /// Fourteen days, oldest first; a filled dot is a headache day in its worst
  /// severity's color, today is ringed.
  private var dayStrip: some View {
    HStack(spacing: 0) {
      ForEach(streak.days) { day in
        VStack(spacing: 3) {
          Circle()
            .fill(day.peak.map({ colorTheme.color(for: $0) }) ?? Color.secondary.opacity(0.16))
            .frame(width: 11, height: 11)
            .overlay(
              Circle()
                .strokeBorder(Color.primary.opacity(day.isToday ? 0.7 : 0.0), lineWidth: 1.5)
                .frame(width: 15, height: 15))
          Text(String(Calendar.current.veryShortWeekdaySymbols[Calendar.current.component(.weekday, from: day.date) - 1]))
            .font(.system(size: 8, weight: day.isToday ? .bold : .regular))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Last two weeks: \(streak.days.filter({ $0.peak != nil }).count) days with a headache")
  }

}
