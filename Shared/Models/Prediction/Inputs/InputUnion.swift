//
//  InputUnion.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML

/// Model Prediction Input Union Type
class InputUnion: MLFeatureProvider {
  
  var providers: [MLFeatureProvider]
  
  var featureNames: Set<String> {
    get {
      return providers.reduce([], { $0.union($1.featureNames) })
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    for provider in providers {
      if let value = provider.featureValue(for: featureName) {
        return value
      }
    }
    return nil
  }
  
  init(providers: [MLFeatureProvider]) {
    self.providers = providers
  }
  
}
