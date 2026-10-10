//
//  CurrentHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI
import CoreData
import DataController

/// Shows and manages the current headache's UI.
struct CurrentHeadacheView: View {
  
  // MARK: Types
  
  class ViewModel: ObservableObject {

    /// Whether the change severity confirmation alert is visible.
    @Published var showingSeverityConfirmation = false

    /// Whether or not the headache manager needs more not-present headache training data.
    @Published var needsInput: Bool = false

    /// The application's first appearance.
    var firstAppearance: Bool = true

    // MARK: Private properties

    /// The app's headache manager.
    private let headacheManager: HeadacheManager

    /// The app's headache predictor.
    private let predictor: Predictor

    /// The app's refresher.
    private let refresher: Refresher

    // MARK: Initializers

    init(headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
      self.headacheManager = headacheManager
      self.predictor = predictor
      self.refresher = refresher
    }

  }
  
  // MARK: Private properties
  
  /// The app's scene delegate.
  @EnvironmentObject private var sceneDelegate: SceneDelegate
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// The view's model.
  ///
  /// Held as a state object so parent re-renders don't recreate it (which
  /// reset its state and leaked refresh waiters when it was an observed
  /// object created in init).
  @StateObject private var viewModel: ViewModel
  
  /// The headaches fetch request.
  ///
  /// It should ever only return at most one, unresolved, headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The current (unresolved) headache.
  @MainActor private var currentHeadache: Headache? {
    return headaches.first
  }

  /// The app's color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// Whole days headache-free (nil when never had one).
  @State private var daysFree: Int?

  /// The "what changed since last open" digest.
  @State private var digest = RiskDigest(lines: [])

  /// A just-crossed model milestone.
  @State private var milestone: ModelMilestone?

  /// The logged 24h risk forecasts over the last 48h (for the trend sparkline).
  @State private var riskHistory: [HeadacheManager.RiskHistoryPoint] = []

  /// The accuracy over resolved forecasts, for the headline beside the
  /// forecast's confidence grade.
  @State private var observedAccuracy: (accuracy: Double, count: Int)?

  /// The last two weeks and the headache-free runs.
  @State private var streak: StreakSummary?

  /// The cached insights report, for the drivers and their drill-ins.
  @State private var report: InsightsReport?

  /// Where a tap on the hero or a driver leads.
  @State private var route: TrackRoute?

  /// Whether the resolve confirmation is showing.
  @State private var showingResolveConfirmation = false

  /// The written summaries.
  @EnvironmentObject private var summaryService: SummaryService

  // Preferences
  @AppStorage(Preferences.Lists.Keys.outlook) private var showRiskView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.brief) private var showDrivers = Preferences.Lists.Defaults.shown

  /// Called when the application becomes active.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
      List {
        if let currentHeadache = currentHeadache {
          // During a headache: the live headache leads, its cards follow.
          Section {
            ActiveHeadacheHero(severity: currentHeadache.severity, start: currentHeadache.startTime)
              .padding(.horizontal, Tokens.Spacing.gutter)
              .cardListRow()
          }

          HeadacheViews(headache: currentHeadache, allowsResolution: false, allowsEditing: false, allowsDeletion: false, showsAllCards: false, showsStatus: false)
            .id(currentHeadache)
        }
        else if showRiskView, let prediction = predictor.prediction, prediction != .empty {
          // The forecast: score, written summary, and the 48h-into-24h ribbon.
          Section {
            TrackHeroView(
              prediction: prediction,
              accuracy: accuracy(for: prediction),
              history: riskHistory,
              summary: summaryService.risk,
              isWriting: summaryService.isWritingRisk,
              onOpenSignals: { route = .signals })
              .cardListRow()
          } footer: {
            SectionFooterView(title: ([predictor.metrics?.provenanceSummary, "Updated \(prediction.computedAt.formattedNonRelative())"].compactMap({ $0 })).joined(separator: " · ") + ".")
          }

          // What's moving it.
          if showDrivers, !drivers.isEmpty {
            Section {
              DriversStrip(drivers: drivers) { driver in
                route = driver.feature.map(TrackRoute.trigger) ?? .signals
              }
              .cardListRow()
            } header: {
              SectionTitleView(title: "Behind Today's Risk")
            }
          }

          todaySection
        }
        else {
          emptyHeroSection
          todaySection
        }
      }
      .scrollContentBackground(.hidden)
      .background(ambientBackground)
      .navigationTitle("Track")
      .animation(.default, value: predictor.prediction)
      .animation(.default, value: currentHeadache == nil)
      .refreshable {
        await viewModel.forcedPrediction()
        await refreshToday()
      }
      // Logging is always one tap away, above the tab bar.
      .safeAreaInset(edge: .bottom, spacing: 0) {
        SeverityLogBar(
          currentSeverity: currentHeadache?.severity,
          onSeverity: { severity in
            try await viewModel.changeSeverity(to: severity)
            await refreshToday()
          },
          onNoHeadache: viewModel.noHeadacheAction,
          onResolve: { showingResolveConfirmation = true })
      }
      .navigationDestination(item: $route) { route in
        destination(for: route)
      }
      .confirmationDialog("Resolve Headache? It will be available in the Headaches tab.", isPresented: $showingResolveConfirmation, titleVisibility: .visible) {
        AsyncButton("Resolve", role: .destructive) {
          try await viewModel.resolve()
          await refreshToday()
        }
      }
      .toolbar {
        ToolbarItem(placement: .automatic) {
          ListOptionsMenu()
        }
      }
    }
    .onReceive(didBecomeActiveNotificationPublisher) { _ in
      viewModel.didBecomeActive(hasDesiredSeverity: sceneDelegate.desiredSeverity != nil)
    }
    // Also surface the deep-link confirmation when the desired severity is set
    // *after* activation. On a cold launch the URL arrives via `.onOpenURL`,
    // and `SceneDelegate.handle` defers the assignment a runloop — so the
    // didBecomeActive check above can run before it's set and miss the prompt.
    .onChange(of: sceneDelegate.desiredSeverity) { _, newValue in
      if newValue != nil {
        viewModel.showingSeverityConfirmation = true
      }
    }
    .onAppear(perform: viewModel.appeared)
    .onAppear { summaryService.prewarm() }
    .task { await refreshToday() }
    .task(id: summaryTrigger) { updateSummary() }
    .confirmationDialog("Change headache severity to \((sceneDelegate.desiredSeverity ?? .notPresent).title.lowercased())?", isPresented: $viewModel.showingSeverityConfirmation, titleVisibility: .visible) {
      AsyncButton("Change") {
        // Read the desired severity from the live scene delegate; the view
        // model previously held a second instance that could disagree.
        let severity = sceneDelegate.desiredSeverity
        sceneDelegate.desiredSeverity = nil
        if let severity = severity {
          try await viewModel.changeSeverity(to: severity)
        }
      }
      Button("Cancel", role: .cancel) {
        sceneDelegate.desiredSeverity = nil
      }
    }
  }

  init(headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
    _viewModel = StateObject(wrappedValue: ViewModel(headacheManager: headacheManager, predictor: predictor, refresher: refresher))
  }

}

extension CurrentHeadacheView.ViewModel {
  
  @MainActor func setNeedsInput(_ needsInput: Bool) {
    withAnimation { self.needsInput = needsInput }
  }
  
  /// Called when the app becomes active.
  ///
  /// - Parameter hasDesiredSeverity: Whether a widget deep link requested a
  ///   severity change.
  func didBecomeActive(hasDesiredSeverity: Bool) {
    // Were we launched from the widget?
    if hasDesiredSeverity {
      withAnimation {
        showingSeverityConfirmation = true
      }
    }

    // Run a prediction
    Task {
      await nonForcedPrediction()
    }
  }
  
  /// Called when the view appears and reloads the classifier input.
  func appeared() {
    guard !firstAppearance else {
      firstAppearance = false
      return
    }
    
    // Run a prediction
    Task {
      await nonForcedPrediction()
    }
  }
  
  @Sendable func forcedPrediction() async {
    do {
      try await predict(forced: true)
    }
    catch {
      logError("Error forced predicting: \(error)")
    }
  }
  
  func nonForcedPrediction() async {
    do {
      try await predict(forced: false)
    }
    catch {
      logError("Error predicting: \(error)")
    }
  }
  
  /// Updates the classifier input.
  func predict(forced: Bool = true) async throws {
    await setNeedsInput(try await headacheManager.needsTrainingData())
    
    // Check if we should run a prediction
    let now = Date()
    if let lastPredictionDate = predictor.prediction?.computedAt {
      let timeSinceLastPrediction = now.timeIntervalSince(lastPredictionDate)
      guard forced || timeSinceLastPrediction > Constants.Tasks.predictionRefreshInterval else {
        logDebug("Not updating prediction. Minimum interval, \(Constants.Tasks.predictionRefreshInterval), not met with interval \(now.timeIntervalSince(lastPredictionDate)).")
        return
      }
    }
    
    logDebug("Updating current headache view prediction.")

    // Run a prediction, sampling a training row on the clock when the last
    // one is stale (rows should track time, not taps).
    try await headacheManager.createPredict(create: .ifStale(.foreground, maxAge: 3600.0), inWidget: false)

    // Surface the fresh forecast on the risk-gauge Live Activity now. A
    // foreground prediction that newly crosses into high risk otherwise waits
    // for the next app-active reconcile to appear.
    await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)
  }
  
  /// Changes the current headache's severity or creates a new headache if one
  /// doesn't exist.
  ///
  /// - Parameter severity: The new severity.
  func changeSeverity(to severity: Headache.Severity) async throws {
    logDebug("Change severity to \(severity.title).")
    
    // Change the severity
    try await headacheManager.changeSeverity(to: severity)

    if severity == .notPresent {
      // "Not present" resolves the headache — cancel any pending check-in
      // reminder, matching every other resolve path (detail view, widget,
      // watch, notification action). Otherwise a stale "How's your headache?"
      // fires for an already-resolved headache.
      refresher.alertManager.removePendingRequests(withIdentifiers: [HeadacheAlertRequest.checkInRequestIdentifier])
    }
    else {
      // Schedule the follow-up check-in for the now-current headache.
      let identifier = try await headacheManager.currentHeadacheIdentifier()
      try await self.refresher.presentCheckInAlert(with: identifier)
    }

    // Keep the Live Activity in sync
    await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)
  }
  
  /// Resolves the current headache, matching every other resolve path.
  func resolve() async throws {
    logDebug("Resolve current headache from the log bar.")
    try await headacheManager.resolve()
    refresher.alertManager.removePendingRequests(withIdentifiers: [HeadacheAlertRequest.checkInRequestIdentifier])
    await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)
  }

  /// The action to perform if there is no headache.
  func noHeadacheAction() async throws {
    logDebug("No headache action.")
    
    try await headacheManager.createPredict(create: .always(.userAction), inWidget: false)

    // Keep the risk-gauge Live Activity in step with the fresh forecast.
    await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)

    // Check if we should show the not-present training data cell
    await setNeedsInput(try await headacheManager.needsTrainingData())
  }
  
}

// MARK: Today section

extension CurrentHeadacheView {

  /// The current risk tier's theme color (mint/orange/pink), or nil pre-model.
  var tierTint: Color? {
    guard let prediction = predictor.prediction, prediction.probability >= 0 else { return nil }
    return colorTheme.color(for: prediction.tier)
  }

  /// The screen's ambient background — a soft wash of the current risk tier's
  /// color over the grouped background, so the whole screen reflects the state.
  @ViewBuilder var ambientBackground: some View {
    ZStack {
      Color(UIColor.systemGroupedBackground)
      LinearGradient(colors: [(tierTint ?? .clear).opacity(0.16), .clear], startPoint: .top, endPoint: .center)
    }
    .ignoresSafeArea()
    .animation(.easeInOut(duration: 0.6), value: predictor.prediction)
  }

  /// The pre-model hero — anticipation, not emptiness.
  @ViewBuilder var emptyHeroSection: some View {
    Section {
      OutlookHeroView(outlook: .risk(.empty))
        .cardListRow()
    } footer: {
      SectionFooterView(title: "Your forecast is learning your patterns. Keep logging headaches — a personal model turns on after a couple of weeks.")
    }
  }

  /// The Today card: the headache-free run, the last two weeks, and one line
  /// of news.
  @ViewBuilder var todaySection: some View {
    if let streak = streak {
      Section {
        TodayCard(streak: streak, news: milestone?.message ?? digest.lines.first)
          .cardListRow()
      }
    }
  }

  /// The forecast's drivers.
  var drivers: [RiskDriver] {
    guard let prediction = predictor.prediction else {
      return []
    }
    return RiskDriver.make(prediction: prediction, report: report)
  }

  /// The headline accuracy beside the confidence grade.
  func accuracy(for prediction: RiskPrediction) -> ForecastAccuracy? {
    return ForecastAccuracy.headline(observedAccuracy: observedAccuracy?.accuracy, observedCount: observedAccuracy?.count ?? 0, outOfFold: predictor.metrics?.accuracy ?? prediction.modelAccuracy)
  }

  /// Changes whenever the summary's inputs do.
  var summaryTrigger: String {
    let prediction = predictor.prediction
    return "\(prediction?.probability ?? -1)|\(prediction?.computedAt.timeIntervalSince1970 ?? 0)|\(riskHistory.count)|\(report?.generatedAt.timeIntervalSince1970 ?? 0)"
  }

  /// Hands the current facts to the summary service.
  func updateSummary() {
    guard let prediction = predictor.prediction, prediction != .empty else {
      summaryService.update(risk: nil)
      return
    }
    summaryService.update(risk: RiskFacts.make(prediction: prediction, drivers: drivers, history: riskHistory))
  }

  /// The screen a hero or driver tap leads to.
  @ViewBuilder func destination(for route: TrackRoute) -> some View {
    switch route {
    case .signals:
      if let prediction = predictor.prediction {
        ModelInputView(prediction: prediction)
      }
    case .trigger(let feature):
      if let insight = report?.insights.first(where: { $0.feature == feature && $0.target == .occurrence }) {
        TriggerDetailView(insight: insight)
      }
      else if let prediction = predictor.prediction {
        ModelInputView(prediction: prediction)
      }
    }
  }

  /// Recomputes the Today card and advances the last-seen snapshots.
  func refreshToday() async {
    daysFree = HeadacheManager.daysHeadacheFree(since: try? await headacheManager.lastResolvedHeadacheEnd())
    riskHistory = (try? await headacheManager.riskHistory()) ?? []
    if let source = try? await headacheManager.profileSource() {
      streak = StreakSummary.make(episodes: source.episodes, now: Date())
    }

    var debug = Preferences.Debug()

    // Current confident trigger features (non-suggestive onset associations).
    let report = InsightsStore.shared.load()
    self.report = report
    let currentTriggers = Set((report?.insights ?? []).filter { $0.target == .occurrence && $0.confidence != .suggestive }.map { $0.feature })
    let lastTriggers = Set(debug.lastSeenTriggers.compactMap { CorrelationFeature(rawValue: $0) })

    let lastSeen = debug.lastSeenRiskProbability.map {
      RiskPrediction(input: .empty, probability: $0, topFactors: [], computedAt: Date())
    }
    digest = RiskDigest.make(current: predictor.prediction, lastSeen: lastSeen, currentTriggers: currentTriggers, lastTriggers: lastTriggers)

    // The milestone tracks how forecasts have actually done (resolved
    // forecasts), not the training-time validation number, and only once
    // enough have resolved to mean something.
    let hasModel = predictor.modelUpdatedAt != nil
    var currentAccuracy: Double?
    let observed = try? await headacheManager.evaluation()
    observedAccuracy = observed.map({ ($0.accuracy, $0.count) })
    if let observed = observed, observed.count >= ModelMilestone.minimumResolvedCount {
      currentAccuracy = observed.accuracy
    }
    milestone = ModelMilestone.evaluate(hadModel: debug.hadModel, hasModel: hasModel, previousAccuracy: debug.lastProspectiveAccuracy, currentAccuracy: currentAccuracy)

    // Advance the snapshots (only record a real forecast probability).
    if let probability = predictor.prediction?.probability, probability >= 0 {
      debug.lastSeenRiskProbability = probability
    }
    debug.lastSeenTriggers = currentTriggers.map { $0.rawValue }
    debug.hadModel = hasModel
    if let currentAccuracy = currentAccuracy {
      debug.lastProspectiveAccuracy = currentAccuracy
    }
  }
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static let refresher = Refresher()
  static var previews: some View {
    CurrentHeadacheView(headacheManager: Previewing.headacheManager, predictor: Previewing.Prediction.predictor, refresher: refresher)
      .environmentObject(SceneDelegate())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(refresher)
      .environmentObject(SummaryService())
      .onAppear {
        Previewing.Prediction.predictor.prediction = .empty
      }
  }
}

/// Where a tap on the Track tab leads.
enum TrackRoute: Hashable {
  case signals
  case trigger(CorrelationFeature)
}
