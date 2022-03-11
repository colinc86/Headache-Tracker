//
//  ChronologicalInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML

class ChronologicalInput: MLFeatureProvider {
  
  struct FeatureName {
    static let secondsSinceMidnight = "Seconds Since Midnight"
    static let weekday = "Weekday"
  }
  
  /// Seconds Since Midnight as double value
  var Seconds_Since_Midnight: Double
  
  /// Weekday as double value
  var Weekday: Double
  
  var featureNames: Set<String> {
    get {
      return [
        FeatureName.secondsSinceMidnight,
        FeatureName.weekday
      ]
    }
  }
  
  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.secondsSinceMidnight) {
      return MLFeatureValue(double: Seconds_Since_Midnight)
    }
    if (featureName == FeatureName.weekday) {
      return MLFeatureValue(double: Weekday)
    }
    return nil
  }
  
  convenience init(date: Date) {
    self.init(
      Seconds_Since_Midnight: Calendar.current.timeIntervalSinceMidnight(date),
      Weekday: Double(Calendar.current.dayOfWeek(date))
    )
  }
  
  init(Seconds_Since_Midnight: Double, Weekday: Double) {
    self.Seconds_Since_Midnight = Seconds_Since_Midnight
    self.Weekday = Weekday
  }
  
}
