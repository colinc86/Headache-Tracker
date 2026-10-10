//
//  ProfileView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// The Profile tab: who your headaches are. A signature glyph of the signal
/// domains that lead them and a written portrait, then the triggers inline
/// with their data, when headaches start, how one unfolds, what helps, the
/// month, and how honest the forecast has been. Replaces the Analyze tab.
struct ProfileView: View {

  @EnvironmentObject private var headacheManager: HeadacheManager
  @EnvironmentObject private var predictor: Predictor
  @EnvironmentObject private var router: Router
  @EnvironmentObject private var summaryService: SummaryService

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  @State private var analytics: ProfileAnalytics?
  @State private var report: InsightsReport?
  @State private var medications = [ClinicianReportData.MedicationSummary]()
  @State private var recap: MonthlyRecap?
  @State private var evaluationPoints = [EvaluationPoint]()
  @State private var expanded = Set<CorrelationFeature>()
  @State private var showingRecap = false
  @State private var showingSignals = false

  /// The scroll anchor for the triggers (the `insights` deep link).
  private static let triggersAnchor = "profile.triggers"

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: Tokens.Spacing.lg) {
            signatureSection
            triggersSection
              .id(ProfileView.triggersAnchor)
            rhythmSection
            shapeSection
            if !medications.isEmpty {
              MedicationEfficacyCard(medications: medications)
            }
            if let recap = recap, recap.hasData {
              MonthCard(recap: recap) { showingRecap = true }
            }
            forecastSection
          }
          .padding(.bottom, Tokens.Spacing.xxl)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .refreshable { await load(recomputeInsights: true) }
        .onChange(of: router.pendingDestination) { _, destination in
          handle(destination, proxy: proxy)
        }
        .onAppear { handle(router.pendingDestination, proxy: proxy) }
      }
      .navigationTitle("Profile")
      .toolbar {
        if recap?.hasData == true {
          ToolbarItem(placement: .primaryAction) {
            Button {
              showingRecap = true
            } label: {
              Label("Share Your Month", systemImage: "square.and.arrow.up")
            }
          }
        }
      }
      .sheet(isPresented: $showingRecap) {
        MonthlyRecapView()
      }
      .sheet(isPresented: $showingSignals) {
        NavigationStack {
          if let prediction = predictor.prediction, prediction != .empty {
            ModelInputView(prediction: prediction)
          }
          else {
            Text("No forecast yet.")
              .foregroundColor(.secondary)
          }
        }
      }
      .task { await load(recomputeInsights: false) }
    }
  }

  // MARK: Sections

  @ViewBuilder private var signatureSection: some View {
    VStack(spacing: Tokens.Spacing.md) {
      SignatureGlyph(strengths: strengths)
        .frame(maxWidth: 300)
        .padding(.horizontal, Tokens.Spacing.xl)

      if let portrait = summaryService.portrait {
        VStack(spacing: Tokens.Spacing.sm) {
          Text(portrait.headline)
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
          SummaryLine(summary: SummaryText(text: portrait.body, isGenerated: portrait.isGenerated), isWriting: summaryService.isWritingPortrait, alignment: .center)
          if portrait.isGenerated {
            Text("Written on this device with Apple Intelligence from your own data.")
              .font(.caption2)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        .padding(.horizontal, Tokens.Spacing.xl)
      }
    }
    .padding(.top, Tokens.Spacing.sm)
  }

  @ViewBuilder private var triggersSection: some View {
    VStack(spacing: Tokens.Spacing.sm) {
      SectionTitleView(title: "Your Triggers")

      let insights = (report?.insights ?? []).filter({ $0.target == .occurrence })
      if insights.isEmpty {
        Card(title: "Still Learning", systemImage: "sparkle.magnifyingglass", foregroundColor: colorTheme.baseColor) {
          VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("Patterns appear after about \(CorrelationEngine.minimumSampleCount) days of readings and \(CorrelationEngine.minimumEventCount) headaches. Keep logging.")
              .font(.callout)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            stillLearningChips
          }
        }
      }
      else {
        ForEach(insights) { insight in
          ProfileTriggerRow(
            insight: insight,
            line: summaryService.portrait?.insightLines[insight.feature.rawValue] ?? insight.directionDescription,
            isGenerated: summaryService.portrait?.isGenerated == true && summaryService.portrait?.insightLines[insight.feature.rawValue] != nil,
            isExpanded: Binding(
              get: { expanded.contains(insight.feature) },
              set: { isOn in
                if isOn { expanded.insert(insight.feature) } else { expanded.remove(insight.feature) }
              }))
        }
        if !(report?.insufficient ?? []).isEmpty {
          stillLearningChips
            .padding(.horizontal, Tokens.Spacing.gutter)
        }
        SectionFooterView(title: "Associations in your own data, not causes. Each is checked against shuffled data and corrected for testing many signals at once.")
      }
    }
  }

  @ViewBuilder private var stillLearningChips: some View {
    let insufficient = report?.insufficient ?? []
    if !insufficient.isEmpty {
      VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
        Text("Still gathering data")
          .font(.caption.weight(.semibold))
          .foregroundColor(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: Tokens.Spacing.xs) {
            ForEach(insufficient, id: \.feature) { item in
              Chip(title: item.feature.title, systemImage: item.feature.systemImage, style: .readonly)
            }
          }
        }
        .scrollClipDisabled()
      }
    }
  }

  @ViewBuilder private var rhythmSection: some View {
    if let analytics = analytics, analytics.headacheCount > 0 {
      VStack(spacing: Tokens.Spacing.sm) {
        SectionTitleView(title: "When They Start")
        Card(title: "Your Rhythm", systemImage: "clock.fill", foregroundColor: colorTheme.purple, caption: "Each slice is an hour, midnight at the top; each ring a weekday, Sunday innermost. Last \(analytics.windowDays) days.") {
          RhythmClock(
            rhythm: analytics.rhythm,
            tint: colorTheme.purple,
            centerTitle: analytics.typicalOnsetText,
            centerCaption: analytics.peakWeekdayText().map({ "often \($0)" }) ?? "busiest window")
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
        }
      }
    }
  }

  @ViewBuilder private var shapeSection: some View {
    if let analytics = analytics, !analytics.medianCurve.isEmpty {
      VStack(spacing: Tokens.Spacing.sm) {
        SectionTitleView(title: "How One Unfolds")
        Card(title: "Your Typical Headache", systemImage: "waveform.path", foregroundColor: colorTheme.orange, caption: shapeCaption(analytics)) {
          HeadacheShapeChart(curves: analytics.curves, median: analytics.medianCurve, hours: analytics.curveHours, tint: colorTheme.orange)
        }
      }
    }
  }

  @ViewBuilder private var forecastSection: some View {
    let buckets = predictor.metrics?.calibrationBuckets ?? []
    if evaluationPoints.count >= ModelAccuracyCard.minimumResolvedCount || buckets.count >= 2 {
      VStack(spacing: Tokens.Spacing.sm) {
        SectionTitleView(title: "Your Forecast")
        if evaluationPoints.count >= ModelAccuracyCard.minimumResolvedCount {
          ModelAccuracyCard(points: evaluationPoints, metrics: predictor.metrics)
        }
        if buckets.count >= 2 {
          ReliabilityCard(buckets: buckets)
        }
      }
    }
  }

  // MARK: Data

  /// Strength per domain for the glyph.
  private var strengths: [SignalDomain: Double] {
    var strengths = [SignalDomain: Double]()
    for profile in report?.domainProfile ?? [] {
      strengths[profile.domain] = profile.strength
    }
    return strengths
  }

  private func shapeCaption(_ analytics: ProfileAnalytics) -> String {
    var text = "Every headache in the last \(analytics.windowDays) days, lined up at onset. The bold line is the typical one."
    if let duration = analytics.medianDuration {
      text += " Median length \(Formatters.formatInterval(duration))."
    }
    return text
  }

  private func handle(_ destination: Router.Destination?, proxy: ScrollViewProxy) {
    switch destination {
    case .insights:
      withAnimation(Tokens.Motion.reveal) { proxy.scrollTo(ProfileView.triggersAnchor, anchor: .top) }
      router.pendingDestination = nil
    case .signals:
      showingSignals = true
      router.pendingDestination = nil
    case .none:
      break
    }
  }

  private func load(recomputeInsights: Bool) async {
    do {
      report = recomputeInsights ? try await headacheManager.computeInsights() : try await headacheManager.insights()
    }
    catch {
      logError("Profile: error loading insights: \(error)")
      report = InsightsStore.shared.load()
    }

    let source = try? await headacheManager.profileSource()
    let analytics = ProfileAnalytics.make(episodes: source?.episodes ?? [], now: Date())
    self.analytics = analytics
    medications = source?.medications ?? []
    recap = try? await headacheManager.monthlyRecap()
    evaluationPoints = (try? await headacheManager.evaluationSeries()) ?? []

    let observed = try? await headacheManager.evaluation()
    let accuracy = ForecastAccuracy.headline(observedAccuracy: observed?.accuracy, observedCount: observed?.count ?? 0, outOfFold: predictor.metrics?.accuracy)
    summaryService.update(portrait: ProfileFacts.make(analytics: analytics, report: report, medications: medications, accuracy: accuracy))
  }

}
