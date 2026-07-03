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
/// autocorrelated samples across the boundary. Minority classes are balanced
/// by capped duplication on the training slice only.
struct TrainingInput {

  /// The fraction of inputs (oldest first) used for training.
  static let trainingFraction = 0.8

  /// The minimum inputs required before a validation slice is held out.
  static let minimumCountForValidation = 25

  /// The maximum multiple a minority class may be duplicated to.
  static let maximumOversampleMultiple = 3

  let outlookTable: MLDataTable
  let severityTable: MLDataTable
  let onsetTable: MLDataTable
  let durationTable: MLDataTable

  let outlookValidationTable: MLDataTable?
  let severityValidationTable: MLDataTable?
  let onsetValidationTable: MLDataTable?
  let durationValidationTable: MLDataTable?

  /// The medians used to impute missing values, persisted beside the models
  /// so inference imputes identically.
  let medians: FeatureMedians

  /// Whether the input's data tables are valid.
  var isValid: Bool {
    return outlookTable.isValid && severityTable.isValid && onsetTable.isValid && durationTable.isValid
  }

  // MARK: Initializers

  /// Initializes new training input with an array of traning data.
  ///
  /// The training data's volatile labels must already be derived (see
  /// `deriveLabels(from:)`).
  ///
  /// - Parameter trainingData: The training data.
  init(trainingData: [TrainingData]) throws {
    logDebug("Creating training data.")

    // Convert the training data to model inputs, oldest first.
    logDebug("Converting the training data to model inputs.")
    let inputs = trainingData.map({ $0.modelInput }).sorted(by: { $0.date < $1.date })

    // Split chronologically, compute medians from the training slice only,
    // and impute both slices with them.
    let splitIndex = inputs.count >= Self.minimumCountForValidation ? Int(Double(inputs.count) * Self.trainingFraction) : inputs.count
    medians = FeatureMedians.computed(from: Array(inputs[..<splitIndex]))
    let trainingInputs = inputs[..<splitIndex].map(medians.imputing)
    let validationInputs = inputs[splitIndex...].map(medians.imputing)

    logDebug("Getting the data tables (\(trainingInputs.count) training, \(validationInputs.count) validation).")
    outlookTable = try MLDataTable(inputs: TrainingInput.balanceInputs(trainingInputs, forModelType: .outlookClassifier), forModelType: .outlookClassifier)
    severityTable = try MLDataTable(inputs: TrainingInput.balanceInputs(trainingInputs, forModelType: .severityClassifier), forModelType: .severityClassifier)
    onsetTable = try MLDataTable(inputs: TrainingInput.balanceInputs(trainingInputs, forModelType: .onsetRegressor), forModelType: .onsetRegressor)
    durationTable = try MLDataTable(inputs: TrainingInput.balanceInputs(trainingInputs, forModelType: .durationRegressor), forModelType: .durationRegressor)

    outlookValidationTable = try TrainingInput.validationTable(validationInputs, forModelType: .outlookClassifier)
    severityValidationTable = try TrainingInput.validationTable(validationInputs, forModelType: .severityClassifier)
    onsetValidationTable = try TrainingInput.validationTable(validationInputs, forModelType: .onsetRegressor)
    durationValidationTable = try TrainingInput.validationTable(validationInputs, forModelType: .durationRegressor)
  }

  // MARK: Static methods

  /// Builds a validation table for the model type, or nil when the slice
  /// has no usable rows.
  ///
  /// - Parameters:
  ///   - inputs: The (already imputed) validation inputs.
  ///   - modelType: The model type.
  /// - Returns: A data table or nil.
  private static func validationTable(_ inputs: [ModelInput], forModelType modelType: Predictor.ModelType) throws -> MLDataTable? {
    let filtered = filterInputs(inputs, forModelType: modelType)
    guard !filtered.isEmpty else {
      return nil
    }
    return try MLDataTable(inputs: filtered, forModelType: modelType)
  }

  /// Filters the inputs to those usable for the model type.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to filter.
  ///   - modelType: The model type intended to train.
  /// - Returns: The filtered inputs.
  private static func filterInputs(_ inputs: [ModelInput], forModelType modelType: Predictor.ModelType) -> [ModelInput] {
    switch modelType {
    case .durationRegressor:
      return inputs.filter({ $0.timeIntervalUntilNextHeadacheEnd != nil })
    case .onsetRegressor:
      return inputs.filter({ $0.timeIntervalUntilNextHeadacheStart != nil })
    case .severityClassifier, .outlookClassifier:
      return inputs
    }
  }

  /// Balances the inputs for the given model type.
  ///
  /// Classifiers oversample minority classes by duplication up to a cap;
  /// duplication is the honest equivalent of class weights for CreateML
  /// boosted trees, which expose no weighting API.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to balance.
  ///   - modelType: The model type intended to train.
  /// - Returns: The balanced inputs.
  static func balanceInputs(_ inputs: [ModelInput], forModelType modelType: Predictor.ModelType) -> [ModelInput] {
    logDebug("Balance inputs (\(inputs.count)) for model type \(modelType).")

    let filtered = filterInputs(inputs, forModelType: modelType)

    let classOf: (ModelInput) -> String?
    switch modelType {
    case .severityClassifier:
      classOf = { $0.severity.title }
    case .outlookClassifier:
      classOf = { $0.outlook.rawValue }
    case .durationRegressor, .onsetRegressor:
      return filtered
    }

    // Group by class and find the majority count.
    var inputsByClass = [String: [ModelInput]]()
    for input in filtered {
      guard let name = classOf(input) else { continue }
      inputsByClass[name, default: []].append(input)
    }

    guard let majorityCount = inputsByClass.values.map({ $0.count }).max(), majorityCount > 0 else {
      return filtered
    }

    // Duplicate each minority class up to min(majority, cap * original).
    var balanced = filtered
    for (_, classInputs) in inputsByClass {
      let target = min(majorityCount, classInputs.count * Self.maximumOversampleMultiple)
      var deficit = target - classInputs.count
      var index = 0
      while deficit > 0 {
        balanced.append(classInputs[index % classInputs.count])
        index += 1
        deficit -= 1
      }
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

  init(trainingData: [TrainingData]) throws {
  }
}
#endif
