//
//  TriggerSeriesChart.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Charts
import SwiftUI

/// A trigger's daily series with headache episodes as shaded bands, in the
/// same units the association was measured in. Loads its own data; shared by
/// the Profile's inline trigger rows and the trigger detail screen.
struct TriggerSeriesChart: View {

  /// The insight to chart.
  let insight: TriggerInsight

  /// The chart's height.
  var height: CGFloat = 220

  /// The line's tint.
  var tint: Color? = nil

  @EnvironmentObject private var headacheManager: HeadacheManager
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  @State private var series = [DatedValue]()
  @State private var episodes = [HeadacheEpisode]()
  @State private var loaded = false

  private var color: Color {
    return tint ?? colorTheme.baseColor
  }

  /// A headache band clipped to the charted range.
  private struct ChartBand: Identifiable {
    let id: Int
    let start: Date
    let end: Date
  }

  /// A run of consecutive days with no meaningful gap.
  private struct ChartRun: Identifiable {
    let id: Int
    let points: [DatedValue]
  }

  /// The largest gap that stays part of one run.
  private static let maximumRunGap: TimeInterval = 2.0 * 86400.0

  /// Whether the series is personal-baseline z-scores.
  var showsBaselineRelative: Bool {
    return insight.usesBaselineRelative == true
  }

  private var valueAxisLabel: String {
    return showsBaselineRelative ? "σ from your usual" : insight.feature.title
  }

  var body: some View {
    Group {
      if series.isEmpty {
        RoundedRectangle(cornerRadius: Tokens.Radius.sm)
          .fill(Color.secondary.opacity(0.08))
          .overlay {
            Text(loaded ? "No readings in the last six months." : "Loading…")
              .font(.caption)
              .foregroundColor(.secondary)
          }
      }
      else {
        chart
      }
    }
    .frame(height: height)
    .task { await load() }
  }

  private var chart: some View {
    Chart {
      ForEach(chartEpisodes) { band in
        RectangleMark(xStart: .value("Start", band.start), xEnd: .value("End", band.end))
          .foregroundStyle(color.opacity(0.18))
      }

      if showsBaselineRelative {
        RuleMark(y: .value("Baseline", 0.0))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
          .foregroundStyle(Color.secondary.opacity(0.5))
      }

      ForEach(runs) { run in
        ForEach(run.points) { point in
          LineMark(x: .value("Date", point.date, unit: .day), y: .value(valueAxisLabel, point.value), series: .value("Run", run.id))
            .foregroundStyle(color)
            .interpolationMethod(.linear)
        }
        if run.points.count == 1, let point = run.points.first {
          PointMark(x: .value("Date", point.date, unit: .day), y: .value(valueAxisLabel, point.value))
            .symbolSize(18.0)
            .foregroundStyle(color)
        }
      }
    }
    .chartYScale(domain: showsBaselineRelative ? .automatic(includesZero: true) : .automatic(includesZero: false))
  }

  private var runs: [ChartRun] {
    var runs = [ChartRun]()
    var current = [DatedValue]()
    for point in series {
      if let previous = current.last, point.date.timeIntervalSince(previous.date) > TriggerSeriesChart.maximumRunGap {
        runs.append(ChartRun(id: runs.count, points: current))
        current = []
      }
      current.append(point)
    }
    if !current.isEmpty {
      runs.append(ChartRun(id: runs.count, points: current))
    }
    return runs
  }

  private var chartEpisodes: [ChartBand] {
    guard let first = series.first?.date, let last = series.last?.date else {
      return []
    }
    return episodes.enumerated().compactMap { index, episode in
      let end = episode.end ?? Date()
      guard episode.start <= last && end >= first else {
        return nil
      }
      return ChartBand(id: index, start: max(episode.start, first), end: min(end, last))
    }
  }

  private func load() async {
    do {
      let (series, episodes) = try await headacheManager.featureSeries(for: insight.feature, baselineRelative: showsBaselineRelative)
      self.series = series
      self.episodes = episodes
    }
    catch {
      logError("Error loading feature series: \(error)")
    }
    loaded = true
  }

}
