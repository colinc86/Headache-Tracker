//
//  ProfileTriggerRow.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import Charts
import SwiftUI

/// One trigger pattern on the Profile tab: what it means in plain words, how
/// strong and how sure it is, and, expanded in place, the data behind it.
/// Replaces the separate Insights screen.
struct ProfileTriggerRow: View {

  /// The insight.
  let insight: TriggerInsight

  /// The plain-language line (written summary, else the direction).
  let line: String

  /// Whether the line was written by Apple Intelligence.
  let isGenerated: Bool

  /// Whether the data is showing.
  @Binding var isExpanded: Bool

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var color: Color {
    return colorTheme.color(for: insight.feature.domain)
  }

  var body: some View {
    Card(title: insight.feature.title, systemImage: insight.feature.systemImage, foregroundColor: color) {
      InsightConfidenceBadge(confidence: insight.confidence)
    } content: {
      VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
        SummaryLine(summary: SummaryText(text: line, isGenerated: isGenerated), isWriting: false)

        // Strength, lead time, and the confounder flag.
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(color.opacity(0.15))
              Capsule().fill(color)
                .frame(width: max(6.0, geometry.size.width * min(abs(insight.coefficient), 1.0)))
            }
          }
          .frame(height: 6)

          HStack {
            Text("\(insight.strengthLabel.capitalized) link")
            if let lag = insight.bestLagHours {
              Text("· strongest \(lag) h before")
            }
            Spacer()
            Text("\(insight.eventCount) headaches")
          }
          .font(.caption)
          .foregroundColor(.secondary)

          if let other = insight.explainedBy {
            Label("May be explained by \(other.title.lowercased())", systemImage: "arrow.triangle.branch")
              .font(.caption)
              .foregroundColor(colorTheme.confounderFlag)
          }
        }

        if isExpanded {
          VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(insight.usesBaselineRelative == true ? "Daily \(insight.feature.title.lowercased()) against your usual; shaded bands are headaches." : "Daily \(insight.feature.title.lowercased()); shaded bands are headaches.")
              .font(.caption)
              .foregroundColor(.secondary)
            TriggerSeriesChart(insight: insight, height: 160, tint: color)

            if !insight.lagProfile.isEmpty {
              Text("By lead time")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
              Chart(insight.lagProfile.sorted(by: { $0.key < $1.key }), id: \.key) { lag, coefficient in
                BarMark(x: .value("Lead Time", "\(lag) h"), y: .value("Correlation", abs(coefficient)))
                  .foregroundStyle(lag == insight.bestLagHours ? color : color.opacity(0.35))
                  .cornerRadius(3)
              }
              .chartYAxis(.hidden)
              .frame(height: 70)
            }

            NavigationLink {
              TriggerDetailView(insight: insight)
            } label: {
              HStack {
                Text("Statistics and typical values")
                Spacer()
                Image(systemName: "chevron.right")
              }
              .font(.callout.weight(.medium))
              .foregroundColor(color)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }

        Button {
          withAnimation(Tokens.Motion.reveal) { isExpanded.toggle() }
        } label: {
          HStack(spacing: Tokens.Spacing.xs) {
            Text(isExpanded ? "Hide the data" : "Show the data")
            Image(systemName: "chevron.down")
              .rotationEffect(.degrees(isExpanded ? 180 : 0))
          }
          .font(.callout.weight(.medium))
          .foregroundColor(color)
        }
        .buttonStyle(.plain)
      }
    }
  }

}

/// An insight's confidence as the Insights capsule.
struct InsightConfidenceBadge: View {

  let confidence: TriggerInsight.Confidence

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    let color = colorTheme.color(for: confidence)
    Text(confidence.title)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(color.opacity(0.2)))
      .foregroundColor(color)
      .accessibilityLabel("\(confidence.title) confidence")
  }

}
