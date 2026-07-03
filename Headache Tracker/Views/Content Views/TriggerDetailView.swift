//
//  TriggerDetailView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import Charts
import SwiftUI

/// Per-feature drill-in: the feature's time series with headache episodes
/// overlaid, the lag profile, and a pre-onset vs. baseline comparison.
struct TriggerDetailView: View {

  /// The insight to detail.
  let insight: TriggerInsight

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The feature's dated series.
  @State private var series = [DatedValue]()

  /// The headache episodes to overlay.
  @State private var episodes = [HeadacheEpisode]()

  // MARK: View body

  var body: some View {
    List {
      // Association summary
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text(insight.directionDescription)
            .font(.headline)

          Text(summaryText)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
      } header: {
        SectionTitleView(title: insight.target.title)
      }

      // Time series with headache overlays
      if !series.isEmpty {
        Section {
          Chart {
            ForEach(chartEpisodes, id: \.start) { episode in
              RectangleMark(
                xStart: .value("Start", episode.start),
                xEnd: .value("End", episode.end ?? Date())
              )
              .foregroundStyle(colorTheme.baseColor.opacity(0.2))
            }

            ForEach(series) { point in
              LineMark(
                x: .value("Date", point.date),
                y: .value(insight.feature.title, point.value)
              )
              .foregroundStyle(colorTheme.baseColor)
              .interpolationMethod(.monotone)
            }
          }
          .chartYScale(domain: .automatic(includesZero: false))
          .frame(height: 220)
          .padding(.vertical, 8)
        } header: {
          SectionTitleView(title: "\(insight.feature.title) vs. Headaches")
        } footer: {
          SectionFooterView(title: "Shaded bands are logged headaches.")
        }
      }

      // Lag profile
      if !insight.lagProfile.isEmpty {
        Section {
          Chart(insight.lagProfile.sorted(by: { $0.key < $1.key }), id: \.key) { lag, coefficient in
            BarMark(
              x: .value("Lead Time", "\(lag) h"),
              y: .value("Correlation", coefficient)
            )
            .foregroundStyle(lag == insight.bestLagHours ? colorTheme.baseColor : colorTheme.baseColor.opacity(0.4))
          }
          .frame(height: 160)
          .padding(.vertical, 8)
        } header: {
          SectionTitleView(title: "By Lead Time")
        } footer: {
          SectionFooterView(title: "Association between \(insight.feature.title.lowercased()) and a headache starting within each window.")
        }
      }

      // Pre-onset vs. baseline comparison
      Section {
        HStack {
          comparisonColumn(title: insight.target == .occurrence ? "Before headaches" : "During headaches", value: insight.positiveMean)
          Divider()
          comparisonColumn(title: "Baseline", value: insight.baselineMean)
        }
        .padding(.vertical, 4)
      } header: {
        SectionTitleView(title: "Typical Values")
      } footer: {
        SectionFooterView(title: "Average \(insight.feature.title.lowercased()) in each condition, over n=\(insight.sampleCount) samples and \(insight.eventCount) events. Correlation is not causation.")
      }
    }
    .navigationTitle(insight.feature.title)
    .task {
      await load()
    }
  }

  // MARK: Private properties

  /// Episodes clipped to the charted series range.
  private var chartEpisodes: [HeadacheEpisode] {
    guard let first = series.first?.date, let last = series.last?.date else {
      return []
    }
    return episodes.filter { episode in
      episode.start <= last && (episode.end ?? Date()) >= first
    }
  }

  private var summaryText: String {
    let strength: String
    switch abs(insight.coefficient) {
    case 0.5...: strength = "strong"
    case 0.3 ..< 0.5: strength = "moderate"
    default: strength = "weak"
    }

    var text = "A \(strength) association (r = \(String(format: "%.2f", insight.coefficient)), q = \(String(format: "%.3f", insight.qValue)))"
    if insight.usesBaselineRelative == true {
      text += ", measured against your personal baseline"
    }
    if let lag = insight.bestLagHours {
      text += ", strongest in the \(lag) hours before onset"
    }
    if let explainedBy = insight.explainedBy, let partial = insight.partialCoefficient {
      text += ". Controlling for \(explainedBy.title.lowercased()), the association drops to r = \(String(format: "%.2f", partial)) — it may be explained by that signal"
    }
    return text + "."
  }

  // MARK: Private methods

  private func comparisonColumn(title: String, value: Double) -> some View {
    VStack(spacing: 4) {
      Text(insight.feature.format(value))
        .font(.title3.weight(.semibold))
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func load() async {
    do {
      let (series, episodes) = try await headacheManager.featureSeries(for: insight.feature)
      self.series = series
      self.episodes = episodes
    }
    catch {
      logError("Error loading feature series: \(error)")
    }
  }

}
