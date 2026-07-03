//
//  TrainingInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

#if !targetEnvironment(simulator)
import CreateML

/// Creates and houses the tables for training and validation.
///
/// Inputs are split chronologically (the newest 20% held out) so validation
/// measures real forward performance; a random split would leak temporally
/// autocorrelated samples across the boundary. The minority class is
/// balanced by capped duplication on the training slice only.
struct TrainingInput {

  /// The fraction of inputs (oldest first) used for training.
  static let trainingFraction = 0.8

  /// The minimum inputs required before a validation slice is held out.
  static let minimumCountForValidation = 25

  /// The maximum multiple the minority class may be duplicated to.
  static let maximumOversampleMultiple = 3

  /// The training table for the binary risk classifier.
  let riskTable: MLDataTable

  /// The held-out validation table, when enough rows existed.
  let riskValidationTable: MLDataTable?

  /// The held-out validation inputs, for per-row calibration scoring
  /// through the compiled model.
  let riskValidationInputs: [ModelInput]

  /// The medians used to impute missing values, persisted beside the model
  /// so inference imputes identically.
  let medians: FeatureMedians

  /// Whether the input's data table is valid.
  var isValid: Bool {
    return riskTable.isValid
  }

  // MARK: Initializers

  /// Initializes new training input with an array of traning data.
  ///
  /// The training data's volatile labels must already be derived (see
  /// `deriveLabels(from:)`). In-headache rows are excluded — forecasting
  /// risk during a headache is a different regime and would leak.
  ///
  /// - Parameter trainingData: The training data.
  init(trainingData: [TrainingData]) throws {
    logDebug("Creating training data.")

    // Convert to model inputs (oldest first), dropping in-headache rows.
    logDebug("Converting the training data to model inputs.")
    let inputs = trainingData
      .map({ $0.modelInput })
      .filter({ $0.outlook != .headache })
      .sorted(by: { $0.date < $1.date })

    // Split chronologically, compute medians from the training slice only,
    // and impute both slices with them.
    let splitIndex = inputs.count >= Self.minimumCountForValidation ? Int(Double(inputs.count) * Self.trainingFraction) : inputs.count
    medians = FeatureMedians.computed(from: Array(inputs[..<splitIndex]))
    let trainingInputs = inputs[..<splitIndex].map(medians.imputing)
    let validationInputs = inputs[splitIndex...].map(medians.imputing)

    logDebug("Getting the data tables (\(trainingInputs.count) training, \(validationInputs.count) validation).")
    riskTable = try MLDataTable(inputs: TrainingInput.balanced(trainingInputs))
    riskValidationTable = validationInputs.isEmpty ? nil : try MLDataTable(inputs: validationInputs)
    riskValidationInputs = validationInputs
  }

  // MARK: Static methods

  /// Balances the binary classes by duplicating the minority class up to a
  /// cap — the honest equivalent of class weights, which CreateML boosted
  /// trees don't expose.
  ///
  /// - Parameter inputs: The inputs to balance.
  /// - Returns: The balanced inputs.
  static func balanced(_ inputs: [ModelInput]) -> [ModelInput] {
    logDebug("Balance inputs (\(inputs.count)).")

    let positives = inputs.filter({ $0.outlook == .possibleHeadache })
    let negatives = inputs.filter({ $0.outlook != .possibleHeadache })

    let (minority, majority) = positives.count <= negatives.count ? (positives, negatives) : (negatives, positives)
    guard !minority.isEmpty, !majority.isEmpty else {
      return inputs
    }

    let target = min(majority.count, minority.count * Self.maximumOversampleMultiple)
    var balanced = inputs
    var deficit = target - minority.count
    var index = 0
    while deficit > 0 {
      balanced.append(minority[index % minority.count])
      index += 1
      deficit -= 1
    }

    return balanced
  }

}
#else
struct TrainingInput {

  var isValid: Bool {
    return true
  }

  /// The medians used to impute missing values.
  let medians = FeatureMedians()

  /// The held-out validation inputs.
  let riskValidationInputs = [ModelInput]()

  init(trainingData: [TrainingData]) throws {
  }
}
#endif
