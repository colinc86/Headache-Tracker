//
//  WhatIfView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI

/// "Your migraine, simulated." Adjust the signals the model actually leans on
/// and watch it re-score — the result pinned at the top, a sensitivity curve
/// under every slider so a flat response reads as an answer rather than a
/// broken control, and one-tap scenarios built from the user's own baselines.
///
/// Device-only for real numbers — the simulator has no CoreML, so its
/// `Predictor` stub answers with a synthetic response.
struct WhatIfView: View {

  /// The current live input to vary from.
  let baseInput: ModelInput

  // MARK: Private properties

  @EnvironmentObject private var predictor: Predictor
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The scenario — the sliders and the dimensions on offer.
  @State private var scenario: WhatIfScenario?

  /// The scored sensitivity curve per dimension.
  @State private var curves = [String: [CurvePoint]]()

  /// The live forecast's score, the reference for "vs. now".
  @State private var baseScore: ScenarioScore?

  /// The scenario's score as it stands.
  @State private var adjustedScore: ScenarioScore?

  /// The one-tap scenarios on offer.
  @State private var presets = [WhatIfPreset]()

  /// Whether a trained model is available to score.
  @State private var hasModel = true

  @State private var headerTask: Task<Void, Never>?
  @State private var curvesTask: Task<Void, Never>?

  /// Increments when a slider snaps onto "now", driving the haptic.
  @State private var snapTick = 0

  /// The most signals offered before the user adds more.
  private static let initialSignalLimit = 4

  private var isModified: Bool {
    return scenario?.isModified ?? false
  }

  private var yDomain: ClosedRange<Double> {
    return WhatIfScenario.sharedYDomain(curves: Array(curves.values))
  }

  // MARK: View body

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
        if !hasModel {
          Card(
            title: "Simulator Asleep",
            systemImage: "moon.zzz",
            foregroundColor: colorTheme.baseColor,
            caption: "It wakes up after your first on-device training — usually within a day of logging."
          ) {
            Text("Until then the sliders show your readings but can't re-score them.")
              .font(.callout)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        if !presets.isEmpty, let scenario = scenario {
          WhatIfPresetBar(presets: presets, isActive: scenario.isActive, onSelect: select)
        }

        if let scenario = scenario {
          ForEach(scenario.dimensions) { dimension in
            SignalScenarioCard(
              dimension: dimension,
              value: binding(for: dimension),
              initialValue: scenario.initialValues[dimension.id] ?? dimension.range.lowerBound,
              curve: curves[dimension.id] ?? [],
              yDomain: yDomain,
              referenceDate: baseInput.date,
              isEnabled: hasModel,
              onRemove: dimension.isRemovable ? { remove(dimension) } : nil,
              onSnap: { snapTick += 1 })
          }

          if scenario.dimensions.isEmpty {
            Text("No adjustable signals yet. Once the model has readings to work from, they'll show up here.")
              .font(.callout)
              .foregroundColor(.secondary)
              .padding(.horizontal, Tokens.Spacing.gutter)
          }

          addSignalMenu
        }
      }
      .padding(.vertical, Tokens.Spacing.md)
    }
    .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    .safeAreaInset(edge: .top, spacing: 0) {
      WhatIfResultHeader(adjusted: adjustedScore, base: baseScore, isModified: isModified, isEnabled: hasModel)
    }
    .navigationTitle("What If…")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Reset", action: reset)
          .disabled(!isModified)
      }
    }
    .sensoryFeedback(.selection, trigger: snapTick)
    .task {
      await setUp()
    }
  }

  // MARK: Add signal

  /// The adjustable signals not yet on offer, grouped by domain.
  private var remainingSignals: [(domain: SignalDomain, signals: [RiskSignal])] {
    guard let scenario = scenario else {
      return []
    }
    let present = Set(scenario.dimensions.compactMap({ $0.feature }))
    let remaining = WhatIfScenario.adjustable(baseInput.attributionCandidates()).filter { signal in
      guard let feature = signal.correlationFeature, !present.contains(feature) else {
        return false
      }
      return predictor.simulationRange(for: signal).map({ $0.lowerBound < $0.upperBound }) ?? false
    }
    let grouped = Dictionary(grouping: remaining, by: { $0.correlationFeature?.domain ?? .lifestyle })
    return SignalDomain.allCases.compactMap { domain in
      guard let signals = grouped[domain], !signals.isEmpty else {
        return nil
      }
      return (domain, signals.sorted(by: { ($0.correlationFeature?.title ?? "") < ($1.correlationFeature?.title ?? "") }))
    }
  }

  @ViewBuilder private var addSignalMenu: some View {
    let groups = remainingSignals
    if !groups.isEmpty {
      Menu {
        ForEach(groups, id: \.domain) { group in
          Menu(group.domain.title) {
            ForEach(group.signals.indices, id: \.self) { index in
              let signal = group.signals[index]
              Button(signal.correlationFeature?.title ?? "Signal", systemImage: signal.correlationFeature?.systemImage ?? "waveform.path.ecg") {
                add(signal)
              }
            }
          }
        }
      } label: {
        Label("Add Signal", systemImage: "plus.circle")
          .font(.callout.weight(.medium))
          .foregroundColor(colorTheme.baseColor)
          .padding(.horizontal, Tokens.Spacing.gutter)
      }
    }
  }

  // MARK: Actions

  private func binding(for dimension: WhatIfDimension) -> Binding<Double> {
    return Binding(
      get: { scenario?.values[dimension.id] ?? dimension.range.lowerBound },
      set: { newValue in
        guard scenario?.values[dimension.id] != newValue else {
          return
        }
        scenario?.values[dimension.id] = newValue
        scheduleRescore()
      })
  }

  private func reset() {
    withAnimation(Tokens.Motion.selection) {
      scenario?.reset()
    }
    scheduleRescore()
  }

  private func select(_ preset: WhatIfPreset) {
    guard var current = scenario else {
      return
    }
    withAnimation(Tokens.Motion.selection) {
      if current.isActive(preset) {
        current.reset()
      }
      else {
        current.apply(preset)
      }
      scenario = current
    }
    scheduleRescore()
  }

  private func add(_ signal: RiskSignal) {
    guard let dimension = WhatIfDimension(signal: signal, range: predictor.simulationRange(for: signal), isRemovable: true) else {
      return
    }
    withAnimation(Tokens.Motion.selection) {
      scenario?.add(dimension)
    }
    refreshPresets()
    scheduleRescore()
  }

  private func remove(_ dimension: WhatIfDimension) {
    withAnimation(Tokens.Motion.selection) {
      scenario?.remove(id: dimension.id)
      curves[dimension.id] = nil
    }
    refreshPresets()
    scheduleRescore()
  }

  // MARK: Building the simulation

  private func setUp() async {
    guard scenario == nil else {
      return
    }

    let candidates = baseInput.attributionCandidates()
    let ranked = WhatIfScenario.rankSignals(
      candidates: candidates,
      contributions: predictor.prediction?.contributions ?? [],
      importances: predictor.featureImportances(),
      limit: WhatIfView.initialSignalLimit)

    var dimensions = [WhatIfDimension.timeOfDay]
    for signal in ranked {
      if let dimension = WhatIfDimension(signal: signal, range: predictor.simulationRange(for: signal), isRemovable: false) {
        dimensions.append(dimension)
      }
    }

    scenario = WhatIfScenario(baseInput: baseInput, dimensions: dimensions)
    refreshPresets()

    let base = try? await predictor.scores(for: [baseInput], includeInterval: true).first
    baseScore = base
    hasModel = base?.hasModel ?? false
    adjustedScore = base
    scheduleRescore()
  }

  private func refreshPresets() {
    guard let scenario = scenario else {
      presets = []
      return
    }
    presets = WhatIfScenario.presets(
      dimensions: scenario.dimensions,
      initialValues: scenario.initialValues,
      baselines: InsightsStore.shared.load()?.baselines ?? [:])
  }

  // MARK: Scoring

  /// Re-scores in two steps so the header leads: the adjusted input alone at
  /// once, then every sensitivity curve in one debounced batch. Every curve
  /// holds the other sliders where the user has them, so any move
  /// invalidates them all.
  private func scheduleRescore() {
    headerTask?.cancel()
    curvesTask?.cancel()

    guard hasModel, let scenario = scenario else {
      return
    }

    headerTask = Task {
      let score = try? await predictor.scores(for: [scenario.input()], includeInterval: true).first
      guard !Task.isCancelled, let score = score else {
        return
      }
      withAnimation(Tokens.Motion.selection) {
        adjustedScore = score
      }
    }

    curvesTask = Task {
      try? await Task.sleep(nanoseconds: 150_000_000)
      guard !Task.isCancelled else {
        return
      }

      let sweeps = scenario.sweepInputs()
      let inputs = sweeps.flatMap({ $0.inputs })
      let scored = try? await predictor.scores(for: inputs)
      guard !Task.isCancelled, let scored = scored, scored.count == inputs.count else {
        return
      }

      var built = [String: [CurvePoint]]()
      var index = 0
      for sweep in sweeps {
        var points = [CurvePoint]()
        for (offset, value) in sweep.values.enumerated() {
          points.append(CurvePoint(id: offset, value: value, probability: scored[index].probability24))
          index += 1
        }
        built[sweep.id] = points
      }
      curves = built
    }
  }

  // MARK: Static forwarders (kept for existing tests)

  static func sweepValues(in range: ClosedRange<Double>, count: Int) -> [Double] {
    return WhatIfScenario.sweepValues(in: range, count: count)
  }

  static func rankSignals(
    candidates: [RiskSignal],
    contributions: [RiskPrediction.RiskContribution],
    importances: [String: Double],
    limit: Int
  ) -> [RiskSignal] {
    return WhatIfScenario.rankSignals(candidates: candidates, contributions: contributions, importances: importances, limit: limit)
  }

}

#Preview {
  NavigationStack {
    WhatIfView(baseInput: Previewing.Prediction.prediction.input)
      .environmentObject(Previewing.Prediction.predictor)
  }
}
