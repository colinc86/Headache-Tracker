//
//  ModelInputView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/16/22.
//

import SwiftUI

/// The "Signals" screen behind the risk card: what's raising/easing risk right
/// now, the user's personal trigger profile, and the full input snapshot. Lead
/// with deviation from personal baseline; absence is shown honestly.
struct ModelInputView: View {

  // MARK: Private properties

  @EnvironmentObject private var predictor: Predictor

  @EnvironmentObject private var headacheManager: HeadacheManager

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The cached insights report (trigger profile + per-feature detail).
  @State private var report: InsightsReport?

  /// The accuracy over resolved forecasts, for the headline beside the
  /// confidence grade.
  @State private var observedAccuracy: (accuracy: Double, count: Int)?

  /// The headline accuracy: observed once enough forecasts resolved, else the
  /// training-time out-of-fold number.
  private var accuracy: ForecastAccuracy? {
    return ForecastAccuracy.headline(observedAccuracy: observedAccuracy?.accuracy, observedCount: observedAccuracy?.count ?? 0, outOfFold: predictor.metrics?.accuracy ?? prediction.modelAccuracy)
  }

  /// The forecast this screen was opened with (a snapshot captured at
  /// navigation time). The displayed forecast prefers the live one below.
  private let passedPrediction: RiskPrediction

  init(prediction: RiskPrediction) {
    self.passedPrediction = prediction
  }

  /// The forecast to display: the live prediction from the environment when
  /// there is one, else the snapshot this screen was pushed with. Reading the
  /// live value means every section — including the Weather snapshot — reflects
  /// the latest fetch instead of a copy frozen at navigation time.
  private var prediction: RiskPrediction {
    if let live = predictor.prediction, live != .empty {
      return live
    }
    return passedPrediction
  }

  private var input: ModelInput { prediction.input }

  /// Today's displayable values keyed by correlation feature (weather + the
  /// presence-gated HealthKit reads, already unit-transformed).
  private var values: [CorrelationFeature: Double] { input.correlationValues() }

  /// Baseline z-scores keyed by correlation feature (from the live prediction).
  private var zByFeature: [CorrelationFeature: Double] {
    var result = [CorrelationFeature: Double]()
    for (metric, z) in input.baselineZ ?? [:] {
      if let feature = CorrelationFeature(healthKitData: metric) {
        result[feature] = z
      }
    }
    return result
  }

  // MARK: View body

  var body: some View {
    List {
      headerSection
      contributorsSection
      whatIfSection
      profileSection
      snapshotSection
    }
    .navigationTitle("Signals")
    .onAppear { report = InsightsStore.shared.load() }
    .task {
      observedAccuracy = (try? await headacheManager.evaluation()).map({ ($0.accuracy, $0.count) })
    }
  }

  // MARK: Sections

  @ViewBuilder private var headerSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Text(prediction.probability >= 0 ? prediction.tier.title : "No Forecast Yet")
          .font(.title2.bold())
        if prediction.probability >= 0 {
          Text("\(Int((prediction.probability * 100).rounded()))% chance in the next 24 hours")
            .font(.subheadline)
            .foregroundColor(.secondary)
          if let shortCaption = prediction.shortCaption {
            Text(shortCaption)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          if prediction.interval != nil || prediction.coverage != nil {
            HStack(spacing: Tokens.Spacing.sm) {
              Text(([prediction.interval.map({ "Likely \($0.rangeText)" }), accuracy?.text].compactMap({ $0 })).joined(separator: " · "))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
              ForecastConfidenceBadge(confidence: prediction.confidence)
            }
            .padding(.top, Tokens.Spacing.xxs)
          }
        }
      }
    } footer: {
      // Only a real forecast has an "as of" time; an empty prediction's sentinel
      // date would otherwise read as "As of Jan 1, 1970" beneath "No Forecast Yet".
      if prediction.probability >= 0 {
        SectionFooterView(title: headerFooterText)
      }
    }
  }

  /// "As of …", the training provenance, and how many signals were estimated.
  private var headerFooterText: String {
    var sentences = [String]()
    sentences.append(([
      "As of \(prediction.computedAt.formattedNonRelative())",
      predictor.metrics?.provenanceSummary.map({ $0.replacingOccurrences(of: "Based", with: "based") })
    ].compactMap({ $0 })).joined(separator: " · ") + ".")
    if let coverage = prediction.coverage, coverage.imputedSignals > 0 {
      let count = coverage.imputedSignals
      sentences.append("\(count) signal\(count == 1 ? " wasn't" : "s weren't") available and \(count == 1 ? "was" : "were") filled with your usual values.")
    }
    if let accuracy = accuracy {
      sentences.append(accuracy.sourceDescription)
    }
    return sentences.joined(separator: " ")
  }

  /// What's raising / easing risk right now — quantitative attribution, with a
  /// qualitative fallback before a model exists.
  @ViewBuilder private var contributorsSection: some View {
    if let contributions = prediction.contributions, !contributions.isEmpty {
      let maximum = contributions.map { abs($0.delta) }.max() ?? 1.0
      let raising = contributions.filter { $0.delta > 0 }
      let easing = contributions.filter { $0.delta < 0 }

      if !raising.isEmpty {
        Section {
          ForEach(raising) { contributionRow($0, maximum: maximum) }
        } header: {
          SectionTitleView(title: "Raising Your Risk Now")
        } footer: {
          SectionFooterView(title: "Independent estimates of each signal's effect vs. your usual — they don't add up to the total.")
        }
      }

      if !easing.isEmpty {
        Section {
          ForEach(easing) { contributionRow($0, maximum: maximum) }
        } header: {
          SectionTitleView(title: "In Your Favor Now")
        }
      }
    }
    else if prediction.probability >= 0, let brief = brief, !brief.reasons.isEmpty {
      Section {
        ForEach(brief.reasons, id: \.self) { reason in
          Text(reason).font(.callout)
        }
      } header: {
        SectionTitleView(title: "What's Behind This")
      }
    }
  }

  /// A link into the "what if…" simulator.
  @ViewBuilder private var whatIfSection: some View {
    if prediction.probability >= 0 {
      Section {
        NavigationLink {
          WhatIfView(baseInput: input)
        } label: {
          Label("What If…", systemImage: "slider.horizontal.3")
        }
      } footer: {
        SectionFooterView(title: "Try scenarios — a better night's sleep, a pressure drop, later today — and watch your risk re-score.")
      }
    }
  }

  /// The user's trigger profile, segmented by domain.
  @ViewBuilder private var profileSection: some View {
    let profile = report?.domainProfile ?? []
    if !profile.isEmpty {
      Section {
        Text("Your headaches lean toward " + profile.prefix(3).map { $0.domain.title }.joined(separator: " · ") + ".")
          .font(.callout)
          .foregroundColor(.secondary)
        ForEach(profile.flatMap { $0.insights }.prefix(6)) { insight in
          NavigationLink {
            TriggerDetailView(insight: insight)
          } label: {
            TriggerInsightCell(insight: insight, modelImportance: predictor.featureImportances()[insight.feature.mlFeatureName])
          }
        }
      } header: {
        SectionTitleView(title: "Your Trigger Profile")
      } footer: {
        SectionFooterView(title: "Signals most linked to your headaches over time. Associations, not proof of cause.")
      }
    }
    else {
      Section {
        Text("Your trigger profile appears once you've logged enough — about 30 daily readings and 10 headaches.")
          .font(.callout)
          .foregroundColor(.secondary)
      } header: {
        SectionTitleView(title: "Your Trigger Profile")
      }
    }
  }

  /// The full input snapshot, grouped by domain, with baseline chips.
  @ViewBuilder private var snapshotSection: some View {
    let byDomain = Dictionary(grouping: values.keys, by: { $0.domain })
    ForEach(SignalDomain.allCases.filter { byDomain[$0] != nil }) { domain in
      Section {
        ForEach((byDomain[domain] ?? []).sorted { ($0.title) < ($1.title) }) { feature in
          snapshotRow(feature)
        }
      } header: {
        SectionTitleView(title: domain.title)
      }
    }
  }

  // MARK: Rows

  private func contributionRow(_ contribution: RiskPrediction.RiskContribution, maximum: Double) -> some View {
    let feature = contribution.feature
    let insight = feature.flatMap { f in report?.insights.first { $0.target == .occurrence && $0.feature == f } }

    let row = HStack(spacing: Tokens.Spacing.md) {
      Image(systemName: feature?.systemImage ?? "waveform.path.ecg")
        .foregroundColor(colorTheme.baseColor)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(feature?.title ?? contribution.mlFeatureName)
          .font(.callout)
        GeometryReader { geometry in
          Capsule()
            .fill(colorTheme.baseColor.opacity(contribution.delta > 0 ? 0.9 : 0.35))
            .frame(width: max(4, geometry.size.width * CGFloat(abs(contribution.delta) / max(maximum, 0.0001))), height: 5)
        }
        .frame(height: 5)
      }
      Text(String(format: "%+.0f%%", contribution.delta * 100))
        .font(.callout.monospacedDigit())
        .foregroundColor(.secondary)
    }
    // Collapse the decorative icon and magnitude bar into one spoken phrase so
    // VoiceOver reads "<signal>, raising/easing your risk by N percent" rather
    // than the icon name, title, and bare "+N%" as disconnected fragments.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(feature?.title ?? contribution.mlFeatureName), "
        + "\(contribution.delta > 0 ? "raising your risk" : "easing your risk") "
        + "by \(Int((abs(contribution.delta) * 100).rounded())) percent")

    return Group {
      if let insight = insight {
        NavigationLink { TriggerDetailView(insight: insight) } label: { row }
      }
      else {
        row
      }
    }
  }

  private func snapshotRow(_ feature: CorrelationFeature) -> some View {
    HStack(spacing: Tokens.Spacing.md) {
      Image(systemName: feature.systemImage)
        .foregroundColor(.secondary)
        .frame(width: 24)
      Text(feature.title)
        .font(.callout)
      Spacer()
      if let z = zByFeature[feature] {
        Chip(title: String(format: "%+.1fσ", z), style: .readonly)
      }
      if let value = values[feature] {
        Text(feature.format(value))
          .font(.callout.monospacedDigit())
          .foregroundColor(.secondary)
      }
    }
  }

  // MARK: Helpers

  private var brief: RiskBrief? {
    RiskBriefBuilder.makeBrief(risk: prediction, todayValues: values, report: report)
  }
}

struct ModelInputView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ModelInputView(prediction: Previewing.Prediction.prediction)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.Prediction.predictor)
    }
  }
}
