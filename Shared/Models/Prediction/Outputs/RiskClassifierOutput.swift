//
//  RiskClassifierOutput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

#if !targetEnvironment(simulator)
import CoreML

/// Model Prediction Output Type
class RiskClassifierOutput: MLFeatureInitializable {

  struct FeatureName {
    static let risk = "Risk"
  }

  /// The positive class label.
  static let positiveLabel = "risk"

  /// The negative class label.
  static let negativeLabel = "none"

  /// Source provided by CoreML
  private let provider: MLFeatureProvider

  /// Risk as string value
  lazy var Risk: String = {
    [unowned self] in return self.provider.featureValue(for: FeatureName.risk)?.stringValue ?? ""
  }()

  /// RiskProbability as dictionary of strings to doubles
  lazy var RiskProbability: [String: Double] = {
    [unowned self] in
    let dictionary = self.provider.featureValue(for: "RiskProbability")?.dictionaryValue ?? [:]
    return dictionary.reduce(into: [String: Double]()) { result, entry in
      if let key = entry.key as? String {
        result[key] = entry.value.doubleValue
      }
    }
  }()

  /// The probability of the positive class.
  var positiveProbability: Double {
    return RiskProbability[RiskClassifierOutput.positiveLabel] ?? (Risk == RiskClassifierOutput.positiveLabel ? 1.0 : 0.0)
  }

  var featureNames: Set<String> {
    return self.provider.featureNames
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    return self.provider.featureValue(for: featureName)
  }

  init(Risk: String, RiskProbability: [String: Double]) {
    self.provider = try! MLDictionaryFeatureProvider(dictionary: [FeatureName.risk: MLFeatureValue(string: Risk), "RiskProbability": MLFeatureValue(dictionary: RiskProbability as [AnyHashable: NSNumber])])
  }

  required init(features: MLFeatureProvider) {
    self.provider = features
  }
}
#endif
