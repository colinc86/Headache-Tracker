//
//  DurationRegressorOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/18/22.
//

import CoreML

/// Model Prediction Output Type
class DurationRegressorOutput: MLFeatureInitializable {
  
  struct FeatureName {
    static let duration = "Duration"
  }
  
  /// Source provided by CoreML
  private let provider: MLFeatureProvider
  
  /// Duration as double value
  lazy var Duration: Double = {
    [unowned self] in return self.provider.featureValue(for: FeatureName.duration)!.doubleValue
  }()
  
  var featureNames: Set<String> {
    return self.provider.featureNames
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    return self.provider.featureValue(for: featureName)
  }
  
  init(Duration: Double) {
    self.provider = try! MLDictionaryFeatureProvider(dictionary: [FeatureName.duration: MLFeatureValue(double: Duration)])
  }
  
  required init(features: MLFeatureProvider) {
    self.provider = features
  }
}
