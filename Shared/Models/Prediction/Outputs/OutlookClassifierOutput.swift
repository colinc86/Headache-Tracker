//
//  OutlookClassifierOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/18/22.
//

#if NON_PREVIEW
import CoreML

/// Model Prediction Output Type
class OutlookClassifierOutput: MLFeatureInitializable {
  
  struct FeatureName {
    static let outlook = "Outlook"
  }
  
  /// Source provided by CoreML
  private let provider: MLFeatureProvider
  
  /// Outlook as string value
  lazy var Outlook: String = {
    [unowned self] in return self.provider.featureValue(for: FeatureName.outlook)!.stringValue
  }()
  
  /// OutlookProbability as dictionary of strings to doubles
  lazy var OutlookProbability: [String: Double] = {
    [unowned self] in return self.provider.featureValue(for: "OutlookProbability")!.dictionaryValue as! [String: Double]
  }()
  
  var featureNames: Set<String> {
    return self.provider.featureNames
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    return self.provider.featureValue(for: featureName)
  }
  
  init(Outlook: String, OutlookProbability: [String: Double]) {
    self.provider = try! MLDictionaryFeatureProvider(dictionary: [FeatureName.outlook: MLFeatureValue(string: Outlook), "OutlookProbability": MLFeatureValue(dictionary: OutlookProbability as [AnyHashable: NSNumber])])
  }
  
  required init(features: MLFeatureProvider) {
    self.provider = features
  }
}
#endif
