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
  private let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier)
  
  // MARK: Public properties
  
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
  ///   - outlook: The predicted outlook.
  ///   - onset: The predicted onset.
  ///   - duration: The predicted duration.
  ///   - severity: The predicted severity
  func setPredictionResults(_ outlook: Outlook?, _ onset: Date?, _ duration: TimeInterval?, _ severity: HKCategoryValueSeverity?) {
    predictedOutlook = outlook
    predictedOnset = onset
    predictedDuration = duration
    predictedSeverity = severity
    WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.Widgets.outlookWidgetKind)
  }
  
  /// Sets the current severity and requests a widget reload.
  /// 
  /// - Parameter severity: The current severity.
  func setCurrentSeverity(_ severity: HKCategoryValueSeverity?) {
    currentSeverity = severity
    WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.Widgets.severityWidgetKind)
  }
  
}
