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
  /// iff the row's derived outlook is a possible headache (an onset occurs
  /// within the rolling 24-hour window).
  ///
  /// - Parameter inputs: The (already imputed) model inputs.
  init(inputs: [ModelInput]) throws {
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
      input.outlook == .possibleHeadache ? RiskClassifierOutput.positiveLabel : RiskClassifierOutput.negativeLabel
    }

    try self.init(dictionary: dictionaryInputs)
  }

}
#endif
