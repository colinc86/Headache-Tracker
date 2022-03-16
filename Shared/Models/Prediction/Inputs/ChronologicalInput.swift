//
//  ChronologicalInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import CoreML
import SwiftUI

class ChronologicalInput: MLFeatureProvider {
  
  struct FeatureName {
    static let secondsSinceMidnight = "Seconds Since Midnight"
    static let weekday = "Weekday"
  }
  
  @AppStorage(AppSettings.Predictors.secondsSinceMidnight) var predictorSecondsSinceMidnight = true
  @AppStorage(AppSettings.Predictors.weekday) var predictorWeekday = true
  
  /// Seconds Since Midnight as double value
  var Seconds_Since_Midnight: Double
  
  /// Weekday as double value
  var Weekday: Double
  
  var featureNames: Set<String> {
    get {
      var names = Set<String>()
      if predictorSecondsSinceMidnight {
        names.insert(FeatureName.secondsSinceMidnight)
      }
      if predictorWeekday {
        names.insert(FeatureName.weekday)
      }
      return names
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
