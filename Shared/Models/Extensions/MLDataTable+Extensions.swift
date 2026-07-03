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
  
  init(inputs: [ModelInput], forModelType modelType: Predictor.ModelType) throws {
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
    
    switch modelType {
    case .onsetRegressor:
      dictionaryInputs[OnsetRegressorOutput.FeatureName.onset] = inputs.map({ $0.timeIntervalUntilNextHeadacheStart ?? 0.0 })
    case .durationRegressor:
      dictionaryInputs[DurationRegressorOutput.FeatureName.duration] = inputs.map({ $0.timeIntervalUntilNextHeadacheEnd ?? 0.0 })
    case .outlookClassifier:
      dictionaryInputs[OutlookClassifierOutput.FeatureName.outlook] = inputs.map({ $0.outlook.rawValue })
    case .severityClassifier:
      dictionaryInputs[SeverityClassifierOutput.FeatureName.severity] = inputs.map({ $0.severity.title })
    }
    
    try self.init(dictionary: dictionaryInputs)
  }
  
}
#endif
