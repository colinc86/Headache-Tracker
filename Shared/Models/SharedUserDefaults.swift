//
//  SharedUserDefaults.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/21/22.
//

import Foundation
import HealthKit
import WidgetKit

class SharedUserDefaults {
  
  // MARK: Types
  
  struct Keys {
    static let predictionDate = "prediction.date"
    static let predictedOutlook = "predicted.outlook"
    static let predictedOnset = "predicted.onset"
    static let predictedDuration = "predicted.duration"
    static let predictedSeverity = "predicted.severity"
    static let currentSeverity = "current.severity"
  }
  
  // MARK: Static properties  
  
  /// The shared standard user defaults.
  static let standard = SharedUserDefaults()
  
  // MARK: Private properties
  
  /// The shared defaults.
  private let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
  
  // MARK: Public properties
  
  /// The last prediction date.
  var predictionDate: Date? {
    get {
      return defaults?.value(forKey: Keys.predictionDate) as? Date
    }
    
    set {
      defaults?.set(newValue, forKey: Keys.predictionDate)
      defaults?.synchronize()
    }
  }
  
  /// The predicted outlook.
  var predictedOutlook: Outlook? {
    get {
      if let outlook = defaults?.string(forKey: Keys.predictedOutlook) {
        return Outlook(rawValue: outlook) ?? .noHeadache
      }
      return .noHeadache
    }
    
    set {
      defaults?.set(newValue?.rawValue, forKey: Keys.predictedOutlook)
      defaults?.synchronize()
    }
  }
  
  /// The predicted onset.
  var predictedOnset: Date? {
    get {
      return defaults?.value(forKey: Keys.predictedOnset) as? Date
    }
    
    set {
      defaults?.set(newValue, forKey: Keys.predictedOnset)
      defaults?.synchronize()
    }
  }
  
  /// The predicted duration.
  var predictedDuration: TimeInterval? {
    get {
      return defaults?.value(forKey: Keys.predictedDuration) as? TimeInterval
    }
    
    set {
      defaults?.set(newValue, forKey: Keys.predictedDuration)
      defaults?.synchronize()
    }
  }
  
  /// The predicted severity.
  var predictedSeverity: HKCategoryValueSeverity? {
    get {
      if let rawValue = defaults?.integer(forKey: Keys.predictedSeverity) {
        return HKCategoryValueSeverity(rawValue: rawValue) ?? .notPresent
      }
      return .notPresent
    }
    
    set {
      defaults?.set(newValue?.rawValue, forKey: Keys.predictedSeverity)
      defaults?.synchronize()
    }
  }
  
  /// The current severity.
  var currentSeverity: HKCategoryValueSeverity? {
    get {
      if let rawValue = defaults?.value(forKey: Keys.currentSeverity) as? Int {
        return HKCategoryValueSeverity(rawValue: rawValue)
      }
      return nil
    }
    
    set {
      defaults?.set(newValue?.rawValue, forKey: Keys.currentSeverity)
      defaults?.synchronize()
    }
  }
  
}

extension SharedUserDefaults {
  
  /// Sets the prediction results and requests a widget reload.
  ///
  /// - Parameters:
  ///   - date: The prediction date.
  ///   - outlook: The predicted outlook.
  ///   - onset: The predicted onset.
  ///   - duration: The predicted duration.
  ///   - severity: The predicted severity
  ///   - reloadWidget: Whether the widget's timeline should be reloaded.
  func setPredictionResults(_ date: Date?, _ outlook: Outlook?, _ onset: Date?, _ duration: TimeInterval?, _ severity: HKCategoryValueSeverity?, reloadWidget: Bool) {
    predictionDate = date
    predictedOutlook = outlook
    predictedOnset = onset
    predictedDuration = duration
    predictedSeverity = severity
    
    if reloadWidget {
      WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.outlookWidgetKind)
    }
  }
  
  /// Sets the current severity and requests a widget reload.
  /// 
  /// - Parameter severity: The current severity.
  func setCurrentSeverity(_ severity: HKCategoryValueSeverity?) {
    currentSeverity = severity
    WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.severityWidgetKind)
  }
  
}
