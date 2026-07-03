//
//  SeverityClassifierOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

#if !targetEnvironment(simulator)
import CoreML

/// Model Prediction Output Type
class SeverityClassifierOutput: MLFeatureInitializable {
  
  struct FeatureName {
    static let severity = "Severity"
  }
  
  /// Source provided by CoreML
  private let provider: MLFeatureProvider
  
  /// Severity as string value
  lazy var Severity: String = {
    [unowned self] in return self.provider.featureValue(for: FeatureName.severity)!.stringValue
  }()
  
  /// SeverityProbability as dictionary of strings to doubles
  lazy var SeverityProbability: [String: Double] = {
    [unowned self] in return self.provider.featureValue(for: "SeverityProbability")!.dictionaryValue as! [String: Double]
  }()
  
  var featureNames: Set<String> {
    return self.provider.featureNames
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    return self.provider.featureValue(for: featureName)
  }
  
  init(Severity: String, SeverityProbability: [String: Double]) {
    self.provider = try! MLDictionaryFeatureProvider(dictionary: [FeatureName.severity: MLFeatureValue(string: Severity), "SeverityProbability": MLFeatureValue(dictionary: SeverityProbability as [AnyHashable: NSNumber])])
  }
  
  required init(features: MLFeatureProvider) {
    self.provider = features
  }
}
#endif
