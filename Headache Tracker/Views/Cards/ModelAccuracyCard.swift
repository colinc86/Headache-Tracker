//
//  ModelAccuracyCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Charts
import SwiftUI

/// How the forecasts have actually done: the prospective record of resolved
/// forecasts (what the model said, then what happened), as a trailing
/// two-week accuracy line against the "always say no headache" baseline, with
/// the training-time out-of-fold AUC as a caption.
///
/// Hidden until enough forecasts have resolved to say anything.
struct ModelAccuracyCard: View {

  /// The fewest resolved forecasts before the card shows.
  static let minimumResolvedCount = ForecastAccuracy.minimumObservedCount

  /// How far back the trend line reaches.
  static let trendWindow: TimeInterval = 90.0 * 86400.0

  /// The trailing window each trend point summarizes.
  static let accuracyWindow: TimeInterval = 14.0 * 86400.0

  /// The resolved forecasts, oldest first.
  let points: [EvaluationPoint]

  /// The latest training-time metrics, for the caption.
  let metrics: ModelMetrics?

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The trend line over the recent window.
  private var trend: [ProspectiveAccuracy.WindowPoint] {
    let cutoff = Date().addingTimeInterval(-ModelAccuracyCard.trendWindow)
    return ProspectiveAccuracy.rollingWindows(points.filter({ $0.date >= cutoff }), window: ModelAccuracyCard.accuracyWindow)
  }

  /// The last two weeks of forecasts.
  private var recent: [EvaluationPoint] {
    let cutoff = Date().addingTimeInterval(-ModelAccuracyCard.accuracyWindow)
    return points.filter({ $0.date >= cutoff })
  }

  /// The summary over the whole record (for the baseline line).
  private var overall: ProspectiveAccuracy.Summary {
    return ProspectiveAccuracy.summary(points)
  }

  var body: some View {
    if points.count >= ModelAccuracyCard.minimumResolvedCount {
      Card(
        title: "Forecast Accuracy",
        systemImage: "scope",
        foregroundColor: colorTheme.purple
      ) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
          let recentSummary = ProspectiveAccuracy.summary(recent)
          CardStatRow(
            title: "Last 14 days",
            value: recentSummary.accuracy.map({ String(format: "%.0f%% of %d", $0 * 100.0, recentSummary.count) }) ?? "Not enough forecasts",
            systemImage: "checkmark.circle",
            color: colorTheme.purple)
          CardStatRow(
            title: "Brier score",
            value: recentSummary.brier.map({ String(format: "%.3f", $0) }) ?? overall.brier.map({ String(format: "%.3f", $0) }) ?? "—",
            systemImage: "target",
            color: colorTheme.purple)

          if trend.count >= 2 {
            chart
          }
        }
      } caption: {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
          if let summary = metrics?.rollingSummary {
            Text("Out-of-fold \(summary) at training.")
          }
          Text("Forecasts are logged hourly, so nearby points share information; read the line as a description, not a measurement.")
        }
      }
    }
  }

  /// The trailing-accuracy trend with the majority-class baseline.
  private var chart: some View {
    Chart {
      ForEach(trend) { point in
        LineMark(
          x: .value("Date", point.date),
          y: .value("Accuracy", point.accuracy))
        .interpolationMethod(.monotone)
        .foregroundStyle(colorTheme.purple)
      }

      if let baseline = overall.baseRateAccuracy {
        RuleMark(y: .value("Always no headache", baseline))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [3.0, 3.0]))
          .foregroundStyle(Color.secondary.opacity(0.6))
          .annotation(position: .top, alignment: .leading) {
            Text("always “no headache”")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
      }
    }
    .chartYScale(domain: 0.0 ... 1.0)
    .chartYAxis {
      AxisMarks(position: .trailing, values: [0.0, 0.5, 1.0]) { value in
        AxisValueLabel {
          if let accuracy = value.as(Double.self) {
            Text("\(Int((accuracy * 100).rounded()))%")
              .font(.caption2)
          }
        }
        AxisGridLine()
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 3)) { _ in
        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
          .font(.caption2)
      }
    }
    .frame(height: 96)
  }

}

struct ModelAccuracyCard_Previews: PreviewProvider {
  static var points: [EvaluationPoint] {
    let start = Date().addingTimeInterval(-60.0 * 86400.0)
    return (0 ..< 240).map { index in
      let date = start.addingTimeInterval(TimeInterval(index) * 6.0 * 3600.0)
      let outcome = index % 7 == 0
      let probability = outcome ? (index % 3 == 0 ? 0.3 : 0.8) : (index % 11 == 0 ? 0.7 : 0.2)
      return EvaluationPoint(date: date, probability: probability, outcome: outcome)
    }
  }

  static var previews: some View {
    List {
      ModelAccuracyCard(points: points, metrics: nil)
        .cardListRow()
    }
  }
}
