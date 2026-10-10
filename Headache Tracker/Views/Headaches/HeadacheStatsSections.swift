//
//  HeadacheStatsSections.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// The headache statistics at the top of the Headaches tab: an overview of the
/// chosen period as four tiles, with the severity, onset, and duration charts
/// one tap away. Moved here from the old Analyze tab, where they sat apart
/// from the headaches they describe.
struct HeadacheStatsSections: View {

  /// The resolved headaches since the earliest date.
  @FetchRequest private var resolvedHeadaches: FetchedResults<Headache>

  /// The statistics over the window.
  @State private var statistics: HeadacheStatistics?

  /// The headaches whose onset falls in the window.
  @State private var windowHeadaches = [Headache]()

  /// Whether the charts are showing.
  @AppStorage("settings.headaches.showsCharts") private var showingCharts = false

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The period's unit.
  private let filterUnit: FilterUnit

  /// The period's count.
  private let filterCount: Int

  /// The window's start.
  private let earliestDate: Date

  var body: some View {
    Group {
      Section {
        Card(title: periodTitle, systemImage: "calendar", foregroundColor: colorTheme.baseColor) {
          if let statistics = statistics, !windowHeadaches.isEmpty {
            VStack(spacing: Tokens.Spacing.md) {
              LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Spacing.sm), GridItem(.flexible(), spacing: Tokens.Spacing.sm)], spacing: Tokens.Spacing.sm) {
                StatTile(value: "\(windowHeadaches.count)", label: windowHeadaches.count == 1 ? "headache" : "headaches", color: colorTheme.baseColor)
                rateTile(statistics)
                StatTile(value: statistics.durations.meanDescription, label: "average length", color: colorTheme.green, trend: statistics.durations.meanTrend)
                StatTile(value: "\(daysAffected)", label: daysAffected == 1 ? "day affected" : "days affected", color: colorTheme.cyan)
              }

              Button {
                withAnimation(Tokens.Motion.reveal) { showingCharts.toggle() }
              } label: {
                HStack {
                  Text(showingCharts ? "Hide charts" : "Severity, onset, and duration charts")
                    .font(.callout.weight(.medium))
                  Spacer()
                  Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showingCharts ? 180 : 0))
                }
                .foregroundColor(colorTheme.baseColor)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
          else if statistics != nil {
            Text("Nothing logged in this period. Widen the range above or log a headache.")
              .font(.callout)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .cardListRow()
      } header: {
        SectionTitleView(title: "Overview")
      }

      if showingCharts, let statistics = statistics, !windowHeadaches.isEmpty {
        charts(statistics)
      }
    }
    .onAppear(perform: appeared)
    .onChange(of: resolvedHeadaches.count) { _, _ in appeared() }
  }

  // MARK: Initializers

  /// Creates the sections for a period.
  ///
  /// - Parameters:
  ///   - filterUnit: The period's unit.
  ///   - filterCount: The period's count.
  init(filterUnit: FilterUnit, filterCount: Int) {
    self.filterUnit = filterUnit
    self.filterCount = filterCount
    self.earliestDate = filterUnit.dateBeforeNow(withCount: filterCount)
    let createdAtPredicate = NSPredicate(format: "createdAt >= %@", earliestDate as NSDate)
    let resolvedPredicate = NSPredicate(format: "resolved == %@", NSNumber(booleanLiteral: true))
    _resolvedHeadaches = FetchRequest<Headache>(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [createdAtPredicate, resolvedPredicate]))
  }

  // MARK: Pieces

  private var periodTitle: String {
    return "Last \(filterCount) \(filterUnit.rawValue.capitalized)\(filterCount == 1 ? "" : "s")"
  }

  /// Distinct days with a headache present.
  private var daysAffected: Int {
    var days = Set<Date>()
    for headache in windowHeadaches {
      guard let start = headache.startTime else {
        continue
      }
      for day in ClinicianReportData.spannedDays(from: start, through: headache.endTime ?? Date()) {
        days.insert(day)
      }
    }
    return days.count
  }

  @ViewBuilder private func rateTile(_ statistics: HeadacheStatistics) -> some View {
    switch filterUnit {
    case .year:
      StatTile(value: String(format: "%0.1f", statistics.headachesPerYear), label: "per year", color: colorTheme.purple, trend: statistics.headachesPerYearTrend)
    case .month:
      StatTile(value: String(format: "%0.1f", statistics.headachesPerMonth), label: "per month", color: colorTheme.purple, trend: statistics.headachesPerMonthTrend)
    case .week, .day:
      StatTile(value: String(format: "%0.1f", statistics.headachesPerWeek), label: "per week", color: colorTheme.purple, trend: statistics.headachesPerWeekTrend)
    }
  }

  @ViewBuilder private func charts(_ statistics: HeadacheStatistics) -> some View {
    Section {
      Card(title: "Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
        BlockGraph(series: statistics.severityRanges, earliestDate: earliestDate)
      }
      .cardListRow()
    } header: {
      SectionTitleView(title: "Severity")
    }

    Section {
      Card(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
          BarGraph(
            graphUnit: .severity,
            statistic: statistics.peaks,
            yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
            gradient: Gradient(colors: [colorTheme.cyan.darker(by: 0.1), colorTheme.cyan.lighter(by: 0.1)]),
            earliestDate: earliestDate,
            staticMax: 4)
            .frame(height: 100)
          Divider()
          CardStatRow(title: "Mean", value: statistics.peaks.meanDescription, systemImage: statistics.peaks.meanTrend.systemImage, color: statistics.peaks.meanTrend.foregroundColor(for: colorTheme))
        }
      }
      .cardListRow()
    }

    Section {
      Card(title: "Onset", systemImage: "clock.fill", foregroundColor: colorTheme.purple) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
          BarGraph(
            graphUnit: .time,
            statistic: statistics.onsets,
            yAxis: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"],
            gradient: Gradient(colors: [colorTheme.purple.darker(by: 0.1), colorTheme.purple.lighter(by: 0.1)]),
            earliestDate: earliestDate,
            staticMax: 86400)
            .frame(height: 100)
          Divider()
          CardStatRow(title: "Mean", value: statistics.onsets.meanDescription, systemImage: statistics.onsets.meanTrend.systemImage, color: statistics.onsets.meanTrend.foregroundColor(for: colorTheme))
        }
      }
      .cardListRow()
    } header: {
      SectionTitleView(title: "Onset")
    }

    Section {
      Card(title: "Duration", systemImage: "timer", foregroundColor: colorTheme.green) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
          BarGraph(
            graphUnit: .duration,
            statistic: statistics.durations,
            yAxis: ["0m", Formatters.formatInterval(statistics.durations.max)],
            gradient: Gradient(colors: [colorTheme.green.darker(by: 0.1), colorTheme.green.lighter(by: 0.1)]),
            earliestDate: earliestDate)
            .frame(height: 100)
          Divider()
          VStack(spacing: Tokens.Spacing.sm) {
            CardStatRow(title: "Mean", value: statistics.durations.meanDescription, systemImage: statistics.durations.meanTrend.systemImage, color: statistics.durations.meanTrend.foregroundColor(for: colorTheme))
            CardStatRow(title: "Min", value: statistics.durations.minDescription, systemImage: statistics.durations.minTrend.systemImage, color: statistics.durations.minTrend.foregroundColor(for: colorTheme))
            CardStatRow(title: "Max", value: statistics.durations.maxDescription, systemImage: statistics.durations.maxTrend.systemImage, color: statistics.durations.maxTrend.foregroundColor(for: colorTheme))
          }
        }
      }
      .cardListRow()
    } header: {
      SectionTitleView(title: "Duration")
    }
  }

  // MARK: Loading

  /// Rebuilds the statistics from the fetched headaches, keeping only those
  /// whose onset (not creation) falls in the window, so a back-logged headache
  /// doesn't count toward a window its bars sit outside.
  private func appeared() {
    let now = Date()
    let inWindow = resolvedHeadaches
      .filter({ ($0.startTime ?? now) >= earliestDate })
      .sorted(by: { ($0.startTime ?? now) < ($1.startTime ?? now) })
    windowHeadaches = inWindow
    statistics = HeadacheStatistics(headaches: inWindow, earliestDate: earliestDate)
  }

}

/// One overview number: a value, what it counts, and an optional trend arrow.
struct StatTile: View {

  let value: String
  let label: String
  let color: Color
  var trend: Trend? = nil

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs) {
        Text(value)
          .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
          .foregroundColor(.primary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        if let trend = trend {
          Image(systemName: trend.systemImage)
            .font(.caption.weight(.bold))
            .foregroundColor(trend.foregroundColor(for: colorTheme))
        }
      }
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, Tokens.Spacing.sm)
    .padding(.horizontal, Tokens.Spacing.md)
    .background(RoundedRectangle(cornerRadius: Tokens.Radius.md).fill(color.opacity(0.12)))
    .accessibilityElement(children: .combine)
  }

}

/// A compact statistic row (label · trend · value) styled to sit inside a
/// chart card.
struct CardStatRow: View {

  let title: String
  let value: String
  var systemImage: String? = nil
  var color: Color = .secondary

  var body: some View {
    HStack(spacing: Tokens.Spacing.sm) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .foregroundColor(color)
          .font(.callout)
      }
      Text(title)
        .font(.callout)
      Spacer()
      Text(value)
        .font(.callout.weight(.medium))
        .foregroundColor(.secondary)
    }
  }
}
