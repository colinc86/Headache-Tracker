//
//  OnsetRegressorOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/18/22.
//

#if NON_PREVIEW
import CoreML

/// Model Prediction Output Type
class OnsetRegressorOutput: MLFeatureInitializable {
  
  struct FeatureName {
    static let onset = "Onset"
  }
  
  /// Source provided by CoreML
  private let provider: MLFeatureProvider
  
  /// Onset as double value
  lazy var Onset: Double = {
    [unowned self] in return self.provider.featureValue(for: FeatureName.onset)!.doubleValue
  }()
  
  var featureNames: Set<String> {
    return self.provider.featureNames
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    return self.provider.featureValue(for: featureName)
  }
  
  init(Onset: Double) {
    self.provider = try! MLDictionaryFeatureProvider(dictionary: [FeatureName.onset: MLFeatureValue(double: Onset)])
  }
  
  required init(features: MLFeatureProvider) {
    self.provider = features
  }
}
#endif
