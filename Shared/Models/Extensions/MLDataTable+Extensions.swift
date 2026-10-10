//
//  MLDataTable+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/11/22.
//

#if !targetEnvironment(simulator)
import CreateML
import Foundation

extension MLDataTable {

  /// Builds a table from model inputs with the binary risk target: positive
  /// iff an onset occurs within the horizon's window. The feature columns are
  /// identical across horizons; only the target label differs, so the two
  /// horizons train as separate classifiers on separate tables (never in one
  /// table, which would leak one target into the other as a feature).
  ///
  /// - Parameters:
  ///   - inputs: The (already imputed) model inputs.
  ///   - horizon: The prediction horizon whose label to build.
  init(inputs: [ModelInput], horizon: RiskHorizon = .standard) throws {
    var dictionaryInputs = [String: MLDataValueConvertible]()
    for input in inputs {
      let fullInput = input.fullInput()
      for featureName in fullInput.featureNames {
        let featureValue = fullInput.featureValue(for: featureName)?.doubleValue ?? 0.0
        if var array = dictionaryInputs[featureName] as? [Double] {
          array.append(featureValue)
          dictionaryInputs[featureName] = array
        }
        else {
          dictionaryInputs[featureName] = [featureValue]
        }
      }
    }

    dictionaryInputs[RiskClassifierOutput.FeatureName.risk] = inputs.map { input in
      input.isPositive(horizon: horizon) ? RiskClassifierOutput.positiveLabel : RiskClassifierOutput.negativeLabel
    }

    try self.init(dictionary: dictionaryInputs)
  }

}
#endif
