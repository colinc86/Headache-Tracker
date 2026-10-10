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

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

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
      Section {
        TriggerSeriesChart(insight: insight)
          .padding(.vertical, 8)
      } header: {
        SectionTitleView(title: "\(insight.feature.title) vs. Headaches")
      } footer: {
        SectionFooterView(title: chartFooterText)
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
  }

  // MARK: Private properties

  /// Whether the chart is showing personal-baseline z-scores, matching how
  /// the insight itself was computed.
  private var showsBaselineRelative: Bool {
    return insight.usesBaselineRelative == true
  }

  private var chartFooterText: String {
    let base = showsBaselineRelative
      ? "Daily averages as deviation from your usual (σ), the same view the association was measured on."
      : "Daily averages."
    return base + " Shaded bands are logged headaches; breaks in the line are days without data."
  }

  private var summaryText: String {
    var text = "A \(insight.strengthLabel) association (r = \(String(format: "%.2f", insight.coefficient)), q = \(String(format: "%.3f", insight.qValue)))"
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

}
