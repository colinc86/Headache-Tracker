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
    static let timeOfDaySin = "Time of Day Sin"
    static let timeOfDayCos = "Time of Day Cos"
    static let weekdaySin = "Weekday Sin"
    static let weekdayCos = "Weekday Cos"
  }

  let preferences = Preferences.Predictors()

  /// Sine of the time of day angle.
  var Time_Of_Day_Sin: Double

  /// Cosine of the time of day angle.
  var Time_Of_Day_Cos: Double

  /// Sine of the weekday angle.
  var Weekday_Sin: Double

  /// Cosine of the weekday angle.
  var Weekday_Cos: Double

  var featureNames: Set<String> {
    get {
      var names = Set<String>()
      if preferences.secondsSinceMidnight == true {
        names.insert(FeatureName.timeOfDaySin)
        names.insert(FeatureName.timeOfDayCos)
      }
      if preferences.weekday == true {
        names.insert(FeatureName.weekdaySin)
        names.insert(FeatureName.weekdayCos)
      }
      return names
    }
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    if (featureName == FeatureName.timeOfDaySin) {
      return MLFeatureValue(double: Time_Of_Day_Sin)
    }
    if (featureName == FeatureName.timeOfDayCos) {
      return MLFeatureValue(double: Time_Of_Day_Cos)
    }
    if (featureName == FeatureName.weekdaySin) {
      return MLFeatureValue(double: Weekday_Sin)
    }
    if (featureName == FeatureName.weekdayCos) {
      return MLFeatureValue(double: Weekday_Cos)
    }
    return nil
  }

  convenience init(date: Date) {
    // Encode both cyclic quantities as sine/cosine pairs so 23:59 and 00:01
    // (and Saturday/Sunday) are close in feature space instead of maximally
    // distant.
    let timeOfDayAngle = 2.0 * Double.pi * Calendar.current.timeIntervalSinceMidnight(date) / 86400.0
    let weekdayAngle = 2.0 * Double.pi * Double(Calendar.current.dayOfWeek(date)) / 7.0

    self.init(
      Time_Of_Day_Sin: sin(timeOfDayAngle),
      Time_Of_Day_Cos: cos(timeOfDayAngle),
      Weekday_Sin: sin(weekdayAngle),
      Weekday_Cos: cos(weekdayAngle)
    )
  }

  init(Time_Of_Day_Sin: Double, Time_Of_Day_Cos: Double, Weekday_Sin: Double, Weekday_Cos: Double) {
    self.Time_Of_Day_Sin = Time_Of_Day_Sin
    self.Time_Of_Day_Cos = Time_Of_Day_Cos
    self.Weekday_Sin = Weekday_Sin
    self.Weekday_Cos = Weekday_Cos
  }

}
