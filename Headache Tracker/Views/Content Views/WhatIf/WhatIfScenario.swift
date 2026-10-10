//
//  WhatIfScenario.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import Foundation

/// One adjustable axis of the simulation.
struct WhatIfDimension: Identifiable, Equatable {

  /// What the dimension varies.
  enum Kind: Equatable {
    /// A model signal, set through `ModelInput.settingValue(_:for:)`.
    case signal(RiskSignal)
    /// The input's clock time, in hours since midnight. Time of day is a
    /// model feature in its own right (`Time_Of_Day_Sin/Cos`) and the input
    /// that moves by construction on every hourly refresh.
    case timeOfDay
  }

  /// The identifier for the time-of-day dimension.
  static let timeOfDayID = "timeOfDay"

  /// The time-of-day range in hours; 24 would wrap back to midnight.
  static let timeOfDayRange: ClosedRange<Double> = 0.0 ... 23.99

  let id: String
  let title: String
  let systemImage: String
  let range: ClosedRange<Double>
  let kind: Kind

  /// The correlation feature backing this dimension, for unit formatting.
  let feature: CorrelationFeature?

  /// Whether the user added this dimension (and can remove it).
  var isRemovable = false

  /// The time-of-day dimension.
  static let timeOfDay = WhatIfDimension(
    id: timeOfDayID,
    title: "Time of Day",
    systemImage: "clock",
    range: timeOfDayRange,
    kind: .timeOfDay,
    feature: nil)

  /// A dimension for a signal with a simulation range.
  init?(signal: RiskSignal, range: ClosedRange<Double>?, isRemovable: Bool) {
    guard let range = range, range.lowerBound < range.upperBound, let feature = signal.correlationFeature else {
      return nil
    }
    self.init(id: feature.rawValue, title: feature.title, systemImage: feature.systemImage, range: range, kind: .signal(signal), feature: feature, isRemovable: isRemovable)
  }

  init(id: String, title: String, systemImage: String, range: ClosedRange<Double>, kind: Kind, feature: CorrelationFeature?, isRemovable: Bool = false) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.range = range
    self.kind = kind
    self.feature = feature
    self.isRemovable = isRemovable
  }

  /// A display string for a value on this dimension.
  func format(_ value: Double, referenceDate: Date) -> String {
    switch kind {
    case .timeOfDay:
      let date = Calendar.current.startOfDay(for: referenceDate).addingTimeInterval(value * 3600.0)
      return Formatters.formatTime(date)
    case .signal:
      if let feature = feature {
        return feature.format(value)
      }
      return String(format: "%.1f", value)
    }
  }

  /// Clamps a value to the range.
  func clamp(_ value: Double) -> Double {
    return min(max(value, range.lowerBound), range.upperBound)
  }

}

/// A one-tap scenario built from the user's own data.
struct WhatIfPreset: Identifiable, Equatable {
  let id: String
  let title: String
  let systemImage: String

  /// Dimension id → target value, applied on top of the starting values.
  let values: [String: Double]
}

/// One scored point on a sensitivity curve.
struct CurvePoint: Identifiable, Equatable {
  let id: Int
  let value: Double
  let probability: Double
}

/// The scenario state — what the sliders say — independent of any model, so
/// every rule here is testable on the simulator.
struct WhatIfScenario {

  /// Points scored per sensitivity curve.
  static let sweepCount = 21

  /// The fraction of a range within which a slider snaps to "now".
  static let snapFraction = 0.02

  /// The fraction of a range within which two values count as equal.
  static let equalityFraction = 0.005

  /// The input the scenario varies from.
  let baseInput: ModelInput

  /// The dimensions on offer, time of day first.
  private(set) var dimensions: [WhatIfDimension]

  /// The current slider position per dimension.
  var values: [String: Double]

  /// The positions the sliders started at — a dimension sitting on its
  /// starting value contributes no override, so the resting input equals
  /// `baseInput` even for signals the base never carried.
  private(set) var initialValues: [String: Double]

  init(baseInput: ModelInput, dimensions: [WhatIfDimension]) {
    self.baseInput = baseInput
    self.dimensions = dimensions
    var seeded = [String: Double]()
    for dimension in dimensions {
      seeded[dimension.id] = WhatIfScenario.currentValue(for: dimension, in: baseInput)
    }
    values = seeded
    initialValues = seeded
  }

  // MARK: State

  /// Whether any slider has moved off its starting value.
  var isModified: Bool {
    return dimensions.contains(where: { isModified($0.id) })
  }

  /// Whether a dimension's slider has moved off its starting value.
  func isModified(_ id: String) -> Bool {
    guard let value = values[id], let initial = initialValues[id] else {
      return false
    }
    return value != initial
  }

  /// Returns every slider to its starting value.
  mutating func reset() {
    values = initialValues
  }

  /// Adds a dimension at its current reading.
  mutating func add(_ dimension: WhatIfDimension) {
    guard !dimensions.contains(where: { $0.id == dimension.id }) else {
      return
    }
    dimensions.append(dimension)
    let current = WhatIfScenario.currentValue(for: dimension, in: baseInput)
    values[dimension.id] = current
    initialValues[dimension.id] = current
  }

  /// Removes a dimension.
  mutating func remove(id: String) {
    dimensions.removeAll(where: { $0.id == id })
    values[id] = nil
    initialValues[id] = nil
  }

  /// Applies a preset: its dimensions take the preset's values, every other
  /// dimension returns to its starting value.
  mutating func apply(_ preset: WhatIfPreset) {
    var next = initialValues
    for (id, value) in preset.values {
      guard let dimension = dimensions.first(where: { $0.id == id }) else {
        continue
      }
      next[id] = dimension.clamp(value)
    }
    values = next
  }

  /// Whether the sliders currently sit on a preset.
  func isActive(_ preset: WhatIfPreset) -> Bool {
    for dimension in dimensions {
      guard let value = values[dimension.id] else {
        continue
      }
      let target = preset.values[dimension.id].map(dimension.clamp) ?? initialValues[dimension.id] ?? value
      if !WhatIfScenario.approximatelyEqual(value, target, in: dimension.range) {
        return false
      }
    }
    return !preset.values.isEmpty
  }

  // MARK: Inputs

  /// The base input's own value on a dimension.
  static func currentValue(for dimension: WhatIfDimension, in input: ModelInput) -> Double {
    switch dimension.kind {
    case .timeOfDay:
      let start = Calendar.current.startOfDay(for: input.date)
      return dimension.clamp(input.date.timeIntervalSince(start) / 3600.0)

    case .signal(let signal):
      let value: Double?
      switch signal {
      case .health(let metric):
        value = input.healthKitData?[metric]
      case .weather(let field):
        value = input.weatherStatistics.flatMap({ field.value(from: $0) })
      }
      // No reading: start mid-range rather than at an edge.
      let midpoint = (dimension.range.lowerBound + dimension.range.upperBound) / 2.0
      return dimension.clamp(value ?? midpoint)
    }
  }

  /// The input with every moved slider applied, plus optional per-dimension
  /// overrides (used to sweep one dimension while holding the rest where the
  /// user has them).
  func input(overrides: [String: Double] = [:]) -> ModelInput {
    var input = baseInput

    for dimension in dimensions {
      let override = overrides[dimension.id]
      guard let value = override ?? values[dimension.id] else {
        continue
      }
      // An untouched slider contributes nothing, so an absent signal isn't
      // injected and the resting input stays exactly `baseInput`.
      if override == nil, value == initialValues[dimension.id] {
        continue
      }

      switch dimension.kind {
      case .timeOfDay:
        input.date = Calendar.current.startOfDay(for: baseInput.date).addingTimeInterval(value * 3600.0)
      case .signal(let signal):
        input = input.settingValue(value, for: signal)
      }
    }

    return input
  }

  /// One input per swept value per dimension, each holding the other sliders
  /// where the user has them.
  func sweepInputs(count: Int = WhatIfScenario.sweepCount) -> [(id: String, values: [Double], inputs: [ModelInput])] {
    return dimensions.map { dimension in
      let swept = WhatIfScenario.sweepValues(in: dimension.range, count: count)
      return (dimension.id, swept, swept.map({ input(overrides: [dimension.id: $0]) }))
    }
  }

  // MARK: Pure math

  /// Evenly spaced values spanning a range inclusively.
  static func sweepValues(in range: ClosedRange<Double>, count: Int) -> [Double] {
    guard count > 1 else {
      return [range.lowerBound]
    }
    let step = (range.upperBound - range.lowerBound) / Double(count - 1)
    return (0 ..< count).map({ range.lowerBound + Double($0) * step })
  }

  /// The probability a curve implies at a value: linear between its points,
  /// clamped to its ends.
  static func interpolatedProbability(curve: [CurvePoint], at value: Double) -> Double? {
    let sorted = curve.sorted(by: { $0.value < $1.value })
    guard let first = sorted.first, let last = sorted.last else {
      return nil
    }
    if value <= first.value {
      return first.probability
    }
    if value >= last.value {
      return last.probability
    }
    for (lower, upper) in zip(sorted, sorted.dropFirst()) where value >= lower.value && value <= upper.value {
      let span = upper.value - lower.value
      guard span > 0 else {
        return lower.probability
      }
      let fraction = (value - lower.value) / span
      return lower.probability + (upper.probability - lower.probability) * fraction
    }
    return last.probability
  }

  /// Snaps a value onto the current reading when it lands close to it, so a
  /// slider can rest exactly on "now".
  static func snapped(_ value: Double, toward current: Double, range: ClosedRange<Double>, fraction: Double = snapFraction) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else {
      return value
    }
    return abs(value - current) <= fraction * span ? current : value
  }

  /// Whether two values on a range count as the same slider position.
  static func approximatelyEqual(_ a: Double, _ b: Double, in range: ClosedRange<Double>) -> Bool {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else {
      return a == b
    }
    return abs(a - b) <= equalityFraction * span
  }

  /// One y-domain for every curve, so curves are comparable and a flat one
  /// reads as flat: zero up to the highest probability plus a little air,
  /// never below 35%.
  static func sharedYDomain(curves: [[CurvePoint]]) -> ClosedRange<Double> {
    let highest = curves.flatMap({ $0 }).map({ $0.probability }).max() ?? 0.0
    return 0.0 ... min(1.0, max(0.35, highest + 0.05))
  }

  /// The swing in probability across a curve, or nil without two points.
  static func swing(of curve: [CurvePoint]) -> Double? {
    let probabilities = curve.map({ $0.probability })
    guard curve.count > 1, let lowest = probabilities.min(), let highest = probabilities.max() else {
      return nil
    }
    return highest - lowest
  }

  /// The adjustable signals, ranked by how much the model is relying on them:
  /// this forecast's own attribution first, then the trained model's global
  /// permutation importances, then a sensible static trio. Sleep onset is
  /// excluded: its raw unit is a reference-date interval, not a value a
  /// slider can present.
  static func rankSignals(
    candidates: [RiskSignal],
    contributions: [RiskPrediction.RiskContribution],
    importances: [String: Double],
    limit: Int
  ) -> [RiskSignal] {
    var contributionWeight = [CorrelationFeature: Double]()
    for contribution in contributions {
      guard let feature = contribution.feature else {
        continue
      }
      contributionWeight[feature] = max(contributionWeight[feature] ?? 0.0, abs(contribution.delta))
    }

    // Baseline-Z and slope columns collapse onto the base metric they
    // derive from, so "Sleep Baseline Z" ranks sleep.
    var importanceWeight = [CorrelationFeature: Double]()
    for (name, importance) in importances {
      guard let feature = CorrelationFeature.matching(mlFeatureName: name) else {
        continue
      }
      importanceWeight[feature] = max(importanceWeight[feature] ?? 0.0, importance)
    }

    let fallbackOrder: [CorrelationFeature] = [.sleepSeconds, .pressure, .heartRateVariability]

    func rank(_ signal: RiskSignal) -> Double {
      guard let feature = signal.correlationFeature else {
        return 0.0
      }
      if let contribution = contributionWeight[feature] {
        return 1_000_000.0 + contribution
      }
      if let importance = importanceWeight[feature] {
        return 1_000.0 + importance
      }
      if let index = fallbackOrder.firstIndex(of: feature) {
        return Double(fallbackOrder.count - index)
      }
      return 0.0
    }

    var seen = Set<CorrelationFeature>()
    return adjustable(candidates)
      .filter({ rank($0) > 0.0 })
      .sorted(by: { rank($0) > rank($1) })
      .filter { signal in
        guard let feature = signal.correlationFeature, !seen.contains(feature) else {
          return false
        }
        seen.insert(feature)
        return true
      }
      .prefix(limit)
      .map({ $0 })
  }

  /// The candidates a slider can present.
  static func adjustable(_ candidates: [RiskSignal]) -> [RiskSignal] {
    return candidates.filter({ $0 != .health(.sleepOnset) })
  }

  // MARK: Presets

  /// One-tap scenarios from the user's own baselines. Each appears only when
  /// its dimension is on offer, its baseline is trustworthy, and it would
  /// actually move a slider.
  static func presets(
    dimensions: [WhatIfDimension],
    initialValues: [String: Double],
    baselines: [CorrelationFeature: FeatureBaseline]
  ) -> [WhatIfPreset] {
    func dimension(for feature: CorrelationFeature) -> WhatIfDimension? {
      return dimensions.first(where: { $0.feature == feature })
    }

    func baseline(for feature: CorrelationFeature) -> FeatureBaseline? {
      guard let baseline = baselines[feature], baseline.count >= FeatureBaselines.minimumCount, baseline.std > 0 else {
        return nil
      }
      return baseline
    }

    /// A single-dimension preset, dropped when it wouldn't move the slider.
    func preset(id: String, title: String, systemImage: String, dimension: WhatIfDimension, target: Double) -> WhatIfPreset? {
      let clamped = dimension.clamp(target)
      guard let initial = initialValues[dimension.id], !approximatelyEqual(clamped, initial, in: dimension.range) else {
        return nil
      }
      return WhatIfPreset(id: id, title: title, systemImage: systemImage, values: [dimension.id: clamped])
    }

    var presets = [WhatIfPreset]()

    if let sleep = dimension(for: .sleepSeconds), let baseline = baseline(for: .sleepSeconds), let initial = initialValues[sleep.id] {
      let target = baseline.mean + baseline.std > initial ? baseline.mean + baseline.std : baseline.mean
      if let built = preset(id: "goodSleep", title: "Sleep like a good night", systemImage: "bed.double.fill", dimension: sleep, target: target) {
        presets.append(built)
      }
    }

    if let pressure = dimension(for: .pressure), let initial = initialValues[pressure.id],
       let built = preset(id: "pressureDrop", title: "Pressure falls 1 kPa", systemImage: "arrow.down.right", dimension: pressure, target: initial - 1.0) {
      presets.append(built)
    }

    if let hrv = dimension(for: .heartRateVariability), let baseline = baseline(for: .heartRateVariability),
       let built = preset(id: "calmHRV", title: "Calm HRV", systemImage: "waveform.path.ecg", dimension: hrv, target: baseline.mean + baseline.std) {
      presets.append(built)
    }

    var usual = [String: Double]()
    for dimension in dimensions {
      guard case .signal = dimension.kind, let feature = dimension.feature, let baseline = baseline(for: feature) else {
        continue
      }
      usual[dimension.id] = dimension.clamp(baseline.mean)
    }
    let usualMoves = usual.contains { id, value in
      guard let dimension = dimensions.first(where: { $0.id == id }), let initial = initialValues[id] else {
        return false
      }
      return !approximatelyEqual(value, initial, in: dimension.range)
    }
    if usual.count >= 2, usualMoves {
      presets.append(WhatIfPreset(id: "usual", title: "Everything at my usual", systemImage: "equal.circle", values: usual))
    }

    if let time = dimensions.first(where: { $0.id == WhatIfDimension.timeOfDayID }), let initial = initialValues[time.id], initial < 23.0,
       let built = preset(id: "later", title: "Later today", systemImage: "clock.arrow.circlepath", dimension: time, target: min(initial + 6.0, time.range.upperBound)) {
      presets.append(built)
    }

    return presets
  }

}
