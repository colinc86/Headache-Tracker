//
//  MLDataTable+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/11/22.
//

#if NON_PREVIEW
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
    
    try self.init(dictionary: dictionaryInputs)
  }
  
}
#endif
