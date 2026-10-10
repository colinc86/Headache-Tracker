//
//  ProfileCards.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Charts
import SwiftUI

/// Medication use and how often each helped, from the efficacy ratings on
/// logged doses.
struct MedicationEfficacyCard: View {

  let medications: [ClinicianReportData.MedicationSummary]

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    Card(title: "What Helps", systemImage: "pills.fill", foregroundColor: colorTheme.teal, caption: "From the ratings you give each dose. Rate a dose on its headache to fill this in.") {
      VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
        ForEach(medications.prefix(5)) { medication in
          VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack {
              Text(medication.name)
                .font(.callout.weight(.semibold))
              Spacer()
              Text(medication.ratedCount > 0 ? "helped \(medication.helpfulCount) of \(medication.ratedCount)" : "used \(medication.count)×, not rated")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
            GeometryReader { geometry in
              ZStack(alignment: .leading) {
                Capsule().fill(colorTheme.teal.opacity(0.15))
                if medication.ratedCount > 0 {
                  Capsule().fill(colorTheme.teal)
                    .frame(width: max(6.0, geometry.size.width * CGFloat(medication.helpfulCount) / CGFloat(medication.ratedCount)))
                }
              }
            }
            .frame(height: 8)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

}

/// The month at a glance, with the shareable poster one tap away.
struct MonthCard: View {

  let recap: MonthlyRecap
  let onShare: () -> Void

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    Card(title: recap.monthTitle, systemImage: "calendar", foregroundColor: colorTheme.baseColor) {
      Button(action: onShare) {
        Image(systemName: "square.and.arrow.up")
          .foregroundColor(colorTheme.baseColor)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Share your month")
    } content: {
      LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Spacing.sm), GridItem(.flexible(), spacing: Tokens.Spacing.sm)], spacing: Tokens.Spacing.sm) {
        StatTile(value: "\(recap.headacheFreeDays)/\(recap.totalDays)", label: "headache-free days", color: colorTheme.green)
        StatTile(value: "\(recap.longestFreeStreak)", label: "longest streak", color: colorTheme.teal)
        StatTile(value: "\(recap.headacheCount)", label: recap.headacheCount == 1 ? "headache" : "headaches", color: colorTheme.baseColor)
        if let best = recap.bestWeek, let worst = recap.worstWeek, best.index != worst.index {
          StatTile(value: "Week \(worst.index)", label: "hardest week, \(worst.onsets) headaches", color: colorTheme.orange)
        }
        else {
          StatTile(value: "\(recap.totalDays - recap.headacheFreeDays)", label: "days affected", color: colorTheme.orange)
        }
      }
    }
  }

}

/// How honest the forecast's percentages have been: predicted against
/// observed for each probability bucket, on a diagonal of perfect calibration.
struct ReliabilityCard: View {

  let buckets: [PlattCalibration.Bucket]

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    Card(title: "Does the Percent Hold Up?", systemImage: "scope", foregroundColor: colorTheme.purple, caption: "Each dot is a group of past forecasts: what the model said against how often a headache followed. Dots near the dashed line mean the percent means what it says.") {
      Chart {
        LineMark(x: .value("Said", 0.0), y: .value("Happened", 0.0), series: .value("Line", "ideal"))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
          .foregroundStyle(Color.secondary.opacity(0.6))
        LineMark(x: .value("Said", 1.0), y: .value("Happened", 1.0), series: .value("Line", "ideal"))
          .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
          .foregroundStyle(Color.secondary.opacity(0.6))

        ForEach(buckets, id: \.lowerBound) { bucket in
          PointMark(x: .value("Said", bucket.meanPredicted), y: .value("Happened", bucket.observedRate))
            .symbolSize(CGFloat(min(max(bucket.count, 8), 160)) * 3.0)
            .foregroundStyle(colorTheme.purple.opacity(0.75))
        }
      }
      .chartXScale(domain: 0.0 ... 1.0)
      .chartYScale(domain: 0.0 ... 1.0)
      .chartXAxis {
        AxisMarks(values: [0.0, 0.5, 1.0]) { value in
          AxisGridLine()
          AxisValueLabel { Text("\(Int((value.as(Double.self) ?? 0) * 100))%") }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
          AxisGridLine()
          AxisValueLabel { Text("\(Int((value.as(Double.self) ?? 0) * 100))%") }
        }
      }
      .chartXAxisLabel("Forecast said")
      .chartYAxisLabel("Headache followed")
      .frame(height: 180)
    }
  }

}
