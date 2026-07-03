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

  init() {}
  deinit {}

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

  /// The latest permutation feature importances, normalized to [0, 1].
  ///
  /// - Returns: Importance per feature name.
  func featureImportances() -> [String: Double] {
    return [:]
  }

}
#endif
