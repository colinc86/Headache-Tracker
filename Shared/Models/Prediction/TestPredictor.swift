//
//  TestPredictor.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

#if targetEnvironment(simulator)
/// The simulator stand-in for `Predictor`. CreateML is unavailable on the
/// simulator, so this stub keeps the identical public surface with no-op
/// implementations. When changing `Predictor`'s public API, change this
/// class in lockstep.
class Predictor: ObservableObject {

  // MARK: Types

  enum ModelType {
    case durationRegressor
    case onsetRegressor
    case outlookClassifier
    case severityClassifier
  }

  // MARK: Public properties

  /// Whether or not the predictor is training.
  @Published var training: Bool = false

  /// Whether or not the predictor is ready to predict.
  @Published var ready: Bool = false

  /// The predictor's latest prediction.
  @Published var prediction: RiskPrediction?

  /// The model's last updated at date.
  @Published var modelUpdatedAt: Date?

  /// The date the models were loaded.
  @Published var modelLoadedAt: Date?

  /// The latest validation metrics.
  @Published var metrics: ModelMetrics?

  /// The latest validation metrics for the shorter-horizon classifier.
  @Published var shortMetrics: ModelMetrics?

  /// The latest rolling-origin evaluation of the 24-hour classifier.
  @Published var rolling: RollingOriginResult?

  /// The prediction observer.
  private var predictionObserver: NSObjectProtocol?

  init() {
    // Surface any persisted forecast so the simulator can reach the screens
    // gated on `prediction.probability >= 0` (the Signals "What If…" entry,
    // notably) and the screenshot sweep can capture them. Observing the
    // change matters as much as the initial read: seeding happens after the
    // predictor is constructed, so a one-shot read would pin the stub to
    // whatever the *previous* run left in the shared defaults.
    predictionObserver = Preferences.addPredictionObserver { [weak self] _ in
      DispatchQueue.main.async {
        self?.prediction = Preferences.Shared().currentRisk
      }
    }
    prediction = Preferences.Shared().currentRisk
  }

  deinit {
    if let predictionObserver = predictionObserver {
      Preferences.removePredictionObserver(predictionObserver)
    }
  }

}

// MARK: Public methods

extension Predictor {

  /// Loads the predictor's models.
  func load() async throws {}

  /// Trains the predictor's classifiers.
  ///
  /// - Parameter input: The training input.
  func train(_ input: TrainingInput) async throws {}

  /// Cancels the current training session.
  func cancelTraining() {}

  /// Resets the predictor and its classifiers.
  func reset() {}

  /// Whether the predictor needs to load (or reload) its models.
  func needsLoading() throws -> Bool {
    return false
  }

  /// Makes a prediction.
  ///
  /// - Parameters:
  ///   - input: The predictor's input.
  ///   - inWidget: Whether the method is being called from a widget.
  /// - Returns: The predictor's output.
  @discardableResult
  func predict(_ input: ModelInput, inWidget: Bool) async throws -> RiskPrediction {
    return RiskPrediction.empty
  }

  /// Scores an arbitrary input.
  ///
  /// - Parameter input: The input to score.
  /// - Returns: The synthetic probability.
  func probability(for input: ModelInput) async throws -> Double {
    return try await probabilities(for: [input]).first ?? -1.0
  }

  /// Scores several inputs in one pass.
  ///
  /// CreateML is unavailable here, so this is a deterministic synthetic
  /// response — NOT a forecast. It exists so the what-if explorer is
  /// actually operable (and screenshot-able) on the simulator; returning a
  /// constant made every slider look broken. The shape mirrors the real
  /// model's known directions: less sleep, lower HRV, a bigger pressure
  /// departure, and the early-morning hours all raise risk.
  ///
  /// - Parameter inputs: The inputs to score, in order.
  /// - Returns: One probability per input.
  func probabilities(for inputs: [ModelInput]) async throws -> [Double] {
    return try await scores(for: inputs).map({ $0.probability24 })
  }

  /// Scores several inputs on both horizons: the synthetic response above
  /// for 24 hours, and a lower but equally input-sensitive 12-hour value.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to score, in order.
  ///   - includeInterval: Whether to carry a synthetic 24-hour range, wider
  ///     the fewer signals the input measured.
  /// - Returns: One score per input.
  func scores(for inputs: [ModelInput], includeInterval: Bool = false) async throws -> [ScenarioScore] {
    return inputs.map { input in
      let score = Predictor.syntheticScore(for: input)
      let probability24 = 1.0 / (1.0 + exp(-score))
      var result = ScenarioScore(
        probability24: probability24,
        probability12: 1.0 / (1.0 + exp(-(score - 0.6))))
      if includeInterval {
        let halfWidth = 0.06 + 0.12 * (1.0 - Predictor.syntheticCoverage(for: input).fraction)
        result.interval24 = RiskInterval(lower: max(probability24 - halfWidth, 0.0), upper: min(probability24 + halfWidth, 1.0))
      }
      return result
    }
  }

  /// The coverage the synthetic model would report: the signals it reads,
  /// against what the input measured.
  private static func syntheticCoverage(for input: ModelInput) -> InputCoverage {
    var medians = FeatureMedians()
    medians.healthKit = [.sleepSeconds: 7.0 * 3600.0, .heartRateVariabilitySDNN: 45.0, .restingHeartRate: 60.0, .respiratoryRate: 15.0, .stepCount: 5000.0]
    medians.pressure = 101.3
    medians.humidity = 0.5
    medians.temperature = 20.0
    return medians.coverage(of: input, enabled: { _ in true })
  }

  /// The synthetic logit for an input.
  private static func syntheticScore(for input: ModelInput) -> Double {
    let health = input.healthKitData ?? [:]
    var score = -0.4

    let sleepHours = (health[.sleepSeconds] ?? 7.0 * 3600.0) / 3600.0
    score += (7.0 - sleepHours) * 0.30

    let hrv = health[.heartRateVariabilitySDNN] ?? 45.0
    score += (45.0 - hrv) / 20.0 * 0.40

    if let pressure = input.weatherStatistics?.currentPressure {
      score += abs(pressure - 101.3) * 0.45
    }

    // Risk peaks in the small hours, matching the usual onset pattern.
    let hour = Double(Calendar.current.component(.hour, from: input.date))
    score += cos(hour / 24.0 * 2.0 * Double.pi) * 0.45

    return score
  }

  /// The latest permutation feature importances, normalized to [0, 1].
  ///
  /// A plausible stand-in so the what-if explorer's model-driven signal
  /// ranking is exercised on the simulator instead of always falling through
  /// to its static defaults.
  ///
  /// - Returns: Importance per feature name.
  func featureImportances() -> [String: Double] {
    return [
      "Sleep Baseline Z": 1.0,
      "Sleep Seconds": 0.82,
      "Sigma Pressure": 0.61,
      "Heart Rate Variability": 0.48,
      "Current Pressure": 0.33,
      "Resting Heart Rate": 0.21
    ]
  }

  /// The range to sweep a signal over in the what-if explorer.
  ///
  /// - Parameter signal: The signal to simulate.
  /// - Returns: The range, or nil when the signal has no sensible one.
  func simulationRange(for signal: RiskSignal) -> ClosedRange<Double>? {
    return signal.plausibleBounds
  }

}
#endif
