//
//  RiskSnapshot.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// Everything a risk widget renders, assembled once per timeline from the
/// shared forecast, the current severity, the logged forecast history, and
/// the cached insights report. Pure value type: every derivation lives in the
/// initializer so it can be unit-tested, and nothing here touches HealthKit,
/// weather, location, or the model.
struct RiskSnapshot: Equatable {

  /// How old the forecast is.
  enum Freshness: Equatable {
    case fresh
    case aging
    case stale
    case none
  }

  /// Fresh below this age.
  static let agingAfter: TimeInterval = 90.0 * 60.0

  /// Aging below this age; stale beyond it.
  static let staleAfter: TimeInterval = 6.0 * 3600.0

  /// Where the 24-hour risk is heading versus the last few hours of
  /// forecasts.
  enum Trajectory: Equatable {
    case rising
    case falling
    case steady

    var title: String {
      switch self {
      case .rising: return "Rising"
      case .falling: return "Falling"
      case .steady: return "Steady"
      }
    }

    var systemImage: String {
      switch self {
      case .rising: return "arrow.up.right"
      case .falling: return "arrow.down.right"
      case .steady: return "arrow.right"
      }
    }
  }

  /// The change in the 24-hour probability that counts as movement.
  static let trajectoryDelta = 0.08

  /// The history points a trajectory is measured against: those aged
  /// between one and six hours relative to the forecast.
  static let trajectoryWindow: ClosedRange<TimeInterval> = (1.0 * 3600.0) ... (6.0 * 3600.0)

  /// The minimum reference points for a trajectory.
  static let trajectoryMinimumPoints = 2

  /// Slack for threshold comparisons on probabilities that arrive as
  /// decimals (0.48 − 0.40 is not exactly 0.08 in binary).
  private static let epsilon = 1e-9

  /// Where within the next 24 hours the risk sits, from the ratio of the
  /// 12-hour to the 24-hour probability.
  enum PeakWindow: Equatable {
    case frontLoaded
    case spread
    case building
  }

  /// A 12h/24h ratio at or above this reads as front-loaded.
  static let frontLoadedRatio = 0.75

  /// A 12h/24h ratio at or below this reads as building later.
  static let buildingRatio = 0.40

  /// A headache in progress.
  struct ActiveHeadache: Equatable {
    let severity: Headache.Severity
    let start: Date?
  }

  /// One signal's part in the forecast. `delta` is nil when the row came
  /// from the model's importances (`topFactors`) rather than a signed
  /// contribution, in which case only `direction` is known.
  struct Signal: Equatable, Identifiable {
    let feature: CorrelationFeature?
    let mlFeatureName: String
    let title: String
    let systemImage: String
    let delta: Double?
    let direction: RiskPrediction.RiskFactor.Direction
    let todayValue: Double?
    let baselineMean: Double?

    var id: String {
      return mlFeatureName
    }

    /// Whether the signal is pushing risk up.
    var isRaising: Bool {
      if let delta = delta {
        return delta > 0
      }
      return direction == .elevated
    }

    /// Today's value against the usual one, formatted for a caption.
    var todayVersusUsual: String? {
      guard let feature = feature, let today = todayValue, let baseline = baselineMean else {
        return nil
      }
      return "\(feature.format(today)) vs. usual \(feature.format(baseline))"
    }
  }

  // MARK: Forecast

  /// The 24-hour probability, or nil when there is no forecast.
  let probability24: Double?

  /// The 12-hour probability, when the shorter-horizon model exists.
  let probability12: Double?

  /// The plausible range around the 24-hour probability, when the forecast
  /// carried one.
  let interval24: RiskInterval?

  /// How much of the expected input was measured, when the forecast carried
  /// it.
  let coverage: InputCoverage?

  /// How much to lean on the forecast.
  var confidence: ForecastConfidence {
    return ForecastUncertainty.confidence(interval: interval24, coverage: coverage)
  }

  /// The headline accuracy shown beside the grade, when known.
  let accuracy: ForecastAccuracy?

  var tier24: RiskPrediction.RiskTier? {
    return probability24.map(RiskPrediction.RiskTier.init(probability:))
  }

  var tier12: RiskPrediction.RiskTier? {
    return probability12.map(RiskPrediction.RiskTier.init(probability:))
  }

  /// Whether there is no forecast at all.
  var isEmpty: Bool {
    return probability24 == nil
  }

  // MARK: Age

  /// When the forecast was computed; nil when empty.
  let computedAt: Date?

  /// The moment this snapshot is rendered at (the timeline entry's date).
  let asOf: Date

  /// The forecast's age at `asOf`.
  var age: TimeInterval? {
    return computedAt.map({ asOf.timeIntervalSince($0) })
  }

  /// The forecast's freshness at `asOf`.
  let freshness: Freshness

  var isStale: Bool {
    return freshness == .stale
  }

  // MARK: State

  /// The headache in progress, if any.
  let activeHeadache: ActiveHeadache?

  /// The signals behind the forecast, strongest first.
  let signals: [Signal]

  /// Whether the signals carry signed contributions (device forecasts) or
  /// only importances (older or widget-sourced forecasts).
  var hasSignedSignals: Bool {
    return signals.contains(where: { $0.delta != nil })
  }

  var raising: [Signal] {
    return signals.filter({ $0.isRaising })
  }

  var easing: [Signal] {
    return signals.filter({ !$0.isRaising })
  }

  /// The logged 24-hour forecasts over the trailing window, oldest first,
  /// with the live forecast appended as the newest point.
  let history: [HeadacheManager.RiskHistoryPoint]

  /// The morning-brief reasons, when any apply.
  let brief: RiskBrief?

  /// The user's leading signal domains from Insights, strongest first.
  let profileDomains: [SignalDomain]

  /// Where the risk is heading.
  let trajectory: Trajectory?

  /// Where within the day the risk sits.
  let peakWindow: PeakWindow?

  /// Whether this snapshot stands in for real data (gallery/placeholder).
  var isPlaceholder = false

  /// A one-line reading of when the risk sits.
  var peakWindowText: String {
    switch peakWindow {
    case .frontLoaded: return "Mostly in the next 12 hours"
    case .spread: return "Spread across the day"
    case .building: return "Building through tomorrow"
    case .none:
      switch trajectory {
      case .rising: return "Building through tomorrow"
      case .falling: return "Easing through tomorrow"
      default: return "Across the next 24 hours"
      }
    }
  }

  // MARK: Initializers

  /// Assembles a snapshot.
  ///
  /// - Parameters:
  ///   - risk: The shared forecast.
  ///   - currentSeverity: The logged current severity.
  ///   - headacheStart: The current headache's start, when one is in progress.
  ///   - history: The logged 24-hour forecasts over the trailing window.
  ///   - report: The cached insights report.
  ///   - observedAccuracy: The accuracy and count over resolved forecasts,
  ///     when the data source read them.
  ///   - asOf: The moment the snapshot renders at.
  init(
    risk: RiskPrediction?,
    currentSeverity: Headache.Severity?,
    headacheStart: Date?,
    history: [HeadacheManager.RiskHistoryPoint],
    report: InsightsReport?,
    observedAccuracy: (accuracy: Double, count: Int)? = nil,
    asOf: Date = Date()
  ) {
    self.asOf = asOf

    if let severity = currentSeverity, severity != .notPresent {
      activeHeadache = ActiveHeadache(severity: severity, start: headacheStart)
    }
    else {
      activeHeadache = nil
    }

    let sortedHistory = history.filter({ $0.probability >= 0 }).sorted(by: { $0.date < $1.date })

    guard let risk = risk, risk.probability >= 0 else {
      probability24 = nil
      probability12 = nil
      interval24 = nil
      coverage = nil
      accuracy = nil
      computedAt = nil
      freshness = .none
      signals = []
      self.history = sortedHistory
      brief = nil
      profileDomains = report?.domainProfile.prefix(4).map({ $0.domain }) ?? []
      trajectory = nil
      peakWindow = nil
      return
    }

    probability24 = risk.probability
    probability12 = risk.shortProbability.flatMap({ $0 >= 0 ? $0 : nil })
    interval24 = risk.interval
    coverage = risk.coverage
    accuracy = ForecastAccuracy.headline(observedAccuracy: observedAccuracy?.accuracy, observedCount: observedAccuracy?.count ?? 0, outOfFold: risk.modelAccuracy)
    computedAt = risk.computedAt
    freshness = RiskSnapshot.freshness(forAge: asOf.timeIntervalSince(risk.computedAt))

    // History: the live forecast is appended when it's newer than the last
    // logged point, which both closes the publish-before-record race and
    // makes the sparkline flow into the current value.
    var points = sortedHistory
    if risk.computedAt.timeIntervalSince(points.last?.date ?? .distantPast) > 60.0 {
      points.append(HeadacheManager.RiskHistoryPoint(date: risk.computedAt, probability: risk.probability))
    }
    self.history = points

    // Signals: signed contributions when the forecast has them, else the
    // model's importances.
    let todayValues = risk.input.correlationValues()
    let baselines = report?.baselines ?? [:]
    if let contributions = risk.contributions, !contributions.isEmpty {
      signals = contributions
        .sorted(by: { abs($0.delta) > abs($1.delta) })
        .map { contribution in
          Signal(
            feature: contribution.feature,
            mlFeatureName: contribution.mlFeatureName,
            title: contribution.feature?.title ?? contribution.mlFeatureName,
            systemImage: contribution.feature?.systemImage ?? "waveform.path.ecg",
            delta: contribution.delta,
            direction: contribution.delta > 0 ? .elevated : .reduced,
            todayValue: contribution.feature.flatMap({ todayValues[$0] }),
            baselineMean: contribution.feature.flatMap({ baselines[$0]?.mean }))
        }
    }
    else {
      signals = risk.topFactors.map { factor in
        Signal(
          feature: factor.feature,
          mlFeatureName: factor.mlFeatureName,
          title: factor.feature?.title ?? factor.mlFeatureName,
          systemImage: factor.feature?.systemImage ?? "waveform.path.ecg",
          delta: nil,
          direction: factor.direction,
          todayValue: factor.feature.flatMap({ todayValues[$0] }),
          baselineMean: factor.feature.flatMap({ baselines[$0]?.mean }))
      }
    }

    brief = RiskBriefBuilder.makeBrief(risk: risk, todayValues: todayValues, report: report)
    profileDomains = report?.domainProfile.prefix(4).map({ $0.domain }) ?? []
    trajectory = RiskSnapshot.trajectory(probability: risk.probability, computedAt: risk.computedAt, history: sortedHistory)
    peakWindow = RiskSnapshot.peakWindow(probability24: risk.probability, probability12: probability12)
  }

  /// A private memberwise initializer for `advanced(to:)` and samples.
  private init(
    probability24: Double?, probability12: Double?, interval24: RiskInterval?, coverage: InputCoverage?, accuracy: ForecastAccuracy?, computedAt: Date?, asOf: Date, freshness: Freshness,
    activeHeadache: ActiveHeadache?, signals: [Signal], history: [HeadacheManager.RiskHistoryPoint],
    brief: RiskBrief?, profileDomains: [SignalDomain], trajectory: Trajectory?, peakWindow: PeakWindow?, isPlaceholder: Bool
  ) {
    self.probability24 = probability24
    self.probability12 = probability12
    self.interval24 = interval24
    self.coverage = coverage
    self.accuracy = accuracy
    self.computedAt = computedAt
    self.asOf = asOf
    self.freshness = freshness
    self.activeHeadache = activeHeadache
    self.signals = signals
    self.history = history
    self.brief = brief
    self.profileDomains = profileDomains
    self.trajectory = trajectory
    self.peakWindow = peakWindow
    self.isPlaceholder = isPlaceholder
  }

  /// The same data rendered at a later moment, with its freshness re-derived.
  ///
  /// - Parameter date: The new rendering moment.
  /// - Returns: The re-aged snapshot.
  func advanced(to date: Date) -> RiskSnapshot {
    let freshness = computedAt.map({ RiskSnapshot.freshness(forAge: date.timeIntervalSince($0)) }) ?? .none
    return RiskSnapshot(
      probability24: probability24, probability12: probability12, interval24: interval24, coverage: coverage, accuracy: accuracy, computedAt: computedAt, asOf: date, freshness: freshness,
      activeHeadache: activeHeadache, signals: signals, history: history,
      brief: brief, profileDomains: profileDomains, trajectory: trajectory, peakWindow: peakWindow, isPlaceholder: isPlaceholder)
  }

  /// A copy flagged as placeholder data.
  func asPlaceholder() -> RiskSnapshot {
    var copy = self
    copy.isPlaceholder = true
    return copy
  }

  // MARK: Rules

  /// The freshness for an age; a negative age (clock skew) is fresh.
  static func freshness(forAge age: TimeInterval) -> Freshness {
    if age < agingAfter {
      return .fresh
    }
    if age < staleAfter {
      return .aging
    }
    return .stale
  }

  /// The trajectory of a forecast against the median of the history points
  /// aged within `trajectoryWindow` relative to it.
  static func trajectory(probability: Double, computedAt: Date, history: [HeadacheManager.RiskHistoryPoint]) -> Trajectory? {
    let reference = history
      .filter({ trajectoryWindow.contains(computedAt.timeIntervalSince($0.date)) })
      .map({ $0.probability })
      .sorted()
    guard reference.count >= trajectoryMinimumPoints else {
      return nil
    }

    let middle = reference.count / 2
    let median = reference.count % 2 == 0 ? (reference[middle - 1] + reference[middle]) / 2.0 : reference[middle]
    let delta = probability - median
    if delta >= trajectoryDelta - epsilon {
      return .rising
    }
    if delta <= -trajectoryDelta + epsilon {
      return .falling
    }
    return .steady
  }

  /// Where the risk sits within the day, from the horizon ratio.
  static func peakWindow(probability24: Double, probability12: Double?) -> PeakWindow? {
    guard let probability12 = probability12, probability24 > 0 else {
      return nil
    }
    let ratio = probability12 / probability24
    if ratio >= frontLoadedRatio - epsilon {
      return .frontLoaded
    }
    if ratio <= buildingRatio + epsilon {
      return .building
    }
    return .spread
  }

}

// MARK: - Samples

extension RiskSnapshot {

  /// Representative snapshots for placeholders, the widget gallery, and
  /// previews. Deterministic for a given `asOf`.
  enum Samples {

    /// A gentle 48-hour history ending at the given probability.
    static func history(endingAt probability: Double, asOf: Date) -> [HeadacheManager.RiskHistoryPoint] {
      return (0 ..< 48).map { index in
        let hoursAgo = 47 - index
        let phase = Double(index) / 47.0
        let wave = 0.15 + 0.20 * (1.0 + sin(phase * .pi * 1.6 - 1.2)) / 2.0
        let value = wave + (probability - wave) * pow(phase, 3.0)
        return HeadacheManager.RiskHistoryPoint(date: asOf.addingTimeInterval(-TimeInterval(hoursAgo) * 3600.0 - 20.0 * 60.0), probability: min(max(value, 0.02), 0.98))
      }
    }

    private static func prediction(probability: Double, short: Double?, computedAt: Date, interval: RiskInterval?, coverage: InputCoverage?) -> RiskPrediction {
      var prediction = Previewing.Prediction.prediction
      prediction.probability = probability
      prediction.shortProbability = short
      prediction.computedAt = computedAt
      prediction.interval = interval
      prediction.coverage = coverage
      return prediction
    }

    /// A gentle range and full coverage: grades steady.
    static let steadyLow = (interval: RiskInterval(lower: 0.09, upper: 0.20), coverage: InputCoverage(presentSignals: 11, expectedSignals: 11))

    /// The preview forecast's range and coverage: grades fair.
    static let fairElevated = (interval: RiskInterval(lower: 0.33, upper: 0.52), coverage: InputCoverage(presentSignals: 9, expectedSignals: 11))

    /// A wide range with half the signals estimated: grades rough.
    static let roughHigh = (interval: RiskInterval(lower: 0.61, upper: 0.86), coverage: InputCoverage(presentSignals: 5, expectedSignals: 11))

    private static func report() -> InsightsReport? {
      return InsightsStore.shared.load()
    }

    static func empty(asOf: Date = Date()) -> RiskSnapshot {
      return RiskSnapshot(risk: nil, currentSeverity: nil, headacheStart: nil, history: [], report: nil, asOf: asOf)
    }

    static func low(asOf: Date = Date()) -> RiskSnapshot {
      let computedAt = asOf.addingTimeInterval(-20.0 * 60.0)
      return RiskSnapshot(risk: prediction(probability: 0.14, short: 0.09, computedAt: computedAt, interval: steadyLow.interval, coverage: steadyLow.coverage), currentSeverity: nil, headacheStart: nil, history: history(endingAt: 0.14, asOf: asOf), report: report(), asOf: asOf)
    }

    static func elevated(asOf: Date = Date()) -> RiskSnapshot {
      let computedAt = asOf.addingTimeInterval(-20.0 * 60.0)
      return RiskSnapshot(risk: prediction(probability: 0.42, short: 0.31, computedAt: computedAt, interval: fairElevated.interval, coverage: fairElevated.coverage), currentSeverity: nil, headacheStart: nil, history: history(endingAt: 0.42, asOf: asOf), report: report(), asOf: asOf)
    }

    static func high(asOf: Date = Date()) -> RiskSnapshot {
      let computedAt = asOf.addingTimeInterval(-20.0 * 60.0)
      return RiskSnapshot(risk: prediction(probability: 0.74, short: 0.68, computedAt: computedAt, interval: roughHigh.interval, coverage: roughHigh.coverage), currentSeverity: nil, headacheStart: nil, history: history(endingAt: 0.74, asOf: asOf), report: report(), asOf: asOf)
    }

    static func activeHeadache(asOf: Date = Date()) -> RiskSnapshot {
      let computedAt = asOf.addingTimeInterval(-20.0 * 60.0)
      return RiskSnapshot(risk: prediction(probability: 0.42, short: 0.31, computedAt: computedAt, interval: fairElevated.interval, coverage: fairElevated.coverage), currentSeverity: .moderate, headacheStart: asOf.addingTimeInterval(-70.0 * 60.0), history: history(endingAt: 0.42, asOf: asOf), report: report(), asOf: asOf)
    }

    static func stale(asOf: Date = Date()) -> RiskSnapshot {
      let computedAt = asOf.addingTimeInterval(-7.0 * 3600.0)
      return RiskSnapshot(risk: prediction(probability: 0.42, short: 0.31, computedAt: computedAt, interval: fairElevated.interval, coverage: fairElevated.coverage), currentSeverity: nil, headacheStart: nil, history: history(endingAt: 0.42, asOf: computedAt), report: report(), asOf: asOf)
    }

    /// The gallery/placeholder sample.
    static func placeholder(asOf: Date = Date()) -> RiskSnapshot {
      return elevated(asOf: asOf).asPlaceholder()
    }

  }

}
