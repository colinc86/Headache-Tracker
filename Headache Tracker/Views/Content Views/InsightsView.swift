//
//  InsightsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import SwiftUI

/// Ranked list of possible headache triggers with strength, confidence, and
/// sample counts.
struct InsightsView: View {

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The latest insights report.
  @State private var report: InsightsReport?

  /// The trained models' permutation feature importances.
  @State private var importances = [String: Double]()

  /// Whether the report is being computed.
  @State private var loading = true

  // MARK: View body

  var body: some View {
    List {
      if let report = report {
        if report.insights.isEmpty {
          Section {
            Text("Not enough data yet. Keep logging headaches — correlations need at least \(CorrelationEngine.minimumEventCount) headaches and \(CorrelationEngine.minimumSampleCount) samples per signal.")
              .font(.callout)
              .foregroundColor(.secondary)
          } header: {
            SectionTitleView(title: "Possible Triggers")
          }
        }
        else {
          Section {
            ForEach(report.insights) { insight in
              NavigationLink {
                TriggerDetailView(insight: insight)
              } label: {
                TriggerInsightCell(insight: insight, modelImportance: importances[insight.feature.mlFeatureName])
              }
            }
          } header: {
            SectionTitleView(title: "Possible Triggers")
          } footer: {
            SectionFooterView(title: "Correlation is not causation. These associations are computed from your logged data and can be coincidental.")
          }
        }

        if !report.insufficient.isEmpty {
          Section {
            ForEach(report.insufficient) { item in
              HStack {
                Label(item.feature.title, systemImage: item.feature.systemImage)
                  .foregroundColor(.secondary)
                Spacer()
                Text("n=\(item.sampleCount)")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          } header: {
            SectionTitleView(title: "Not Enough Data")
          } footer: {
            SectionFooterView(title: "These signals don't have enough overlapping samples with your headaches yet.")
          }
        }
      }
      else if loading {
        Section {
          HStack {
            Spacer()
            ProgressView("Analyzing your data…")
            Spacer()
          }
        }
      }
    }
    .navigationTitle("Insights")
    .task(priority: .userInitiated) {
      await load()
    }
    .refreshable {
      await load(force: true)
    }
  }

  // MARK: Private methods

  private func load(force: Bool = false) async {
    loading = true
    defer { loading = false }

    do {
      report = force ? try await headacheManager.computeInsights() : try await headacheManager.insights()
      importances = headacheManager.predictor.featureImportances()
    }
    catch {
      logError("Error loading insights: \(error)")
    }
  }

}

/// A single ranked trigger row.
struct TriggerInsightCell: View {

  /// The insight to display.
  let insight: TriggerInsight

  /// The trained models' importance for this feature, when available.
  var modelImportance: Double?

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme

  // MARK: View body

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label(insight.feature.title, systemImage: insight.feature.systemImage)
          .font(.headline)

        Spacer()

        Image(systemName: insight.higherIsAssociated ? "arrow.up.right" : "arrow.down.right")
          .foregroundColor(colorTheme.baseColor)
      }

      Text(insight.directionDescription)
        .font(.subheadline)
        .foregroundColor(.secondary)

      // Strength bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color(UIColor.tertiarySystemFill))
          Capsule()
            .fill(colorTheme.baseColor)
            .frame(width: max(4.0, geometry.size.width * abs(insight.coefficient)))
        }
      }
      .frame(height: 6)

      HStack {
        Text(insight.confidence.title)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Capsule().fill(confidenceColor.opacity(0.2)))
          .foregroundColor(confidenceColor)

        if let lag = insight.bestLagHours {
          Text("strongest \(lag) h before onset")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        if let modelImportance = modelImportance, modelImportance > 0.3 {
          Label("model", systemImage: "cpu")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
            .foregroundColor(.secondary)
        }

        Spacer()

        Text("n=\(insight.sampleCount), \(insight.eventCount) events")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: Private properties

  private var confidenceColor: Color {
    switch insight.confidence {
    case .strong: return .green
    case .moderate: return .orange
    case .suggestive: return .secondary
    }
  }

}

struct InsightsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      InsightsView()
        .environmentObject(Previewing.headacheManager)
    }
  }
}
