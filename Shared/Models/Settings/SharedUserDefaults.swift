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
    static let currentPrediction = "current.prediction"
    static let currentSeverity = "current.severity"
  }
  
  // MARK: Static properties
  
  /// The notification to signify that the prediction value changed.
  static let predictionDidChangeNotification = Notification.Name(rawValue: "predictionDidChangeNotification")
  
  /// The shared standard user defaults.
  static let standard = SharedUserDefaults()
  
  // MARK: Private properties
  
  /// The shared defaults.
  private let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
  
  // MARK: Public properties
  
  /// The current prediction. Don't set this value directly - use the `setCurrentPrediction`
  /// method instead.
  var currentPrediction: PredictionOutput? {
    get {
      guard let predictionData = defaults?.value(forKey: Keys.currentPrediction) as? Data else {
        return nil
      }
      
      return try? JSONDecoder().decode(PredictionOutput?.self, from: predictionData)
    }
    
    set {
      guard let predictionData = try? JSONEncoder().encode(newValue) else {
        return
      }
      
      defaults?.set(predictionData, forKey: Keys.currentPrediction)
      defaults?.synchronize()
    }
  }
  
  /// The current severity. Don't set this value directly - use the `setCurrentSeverity`
  /// method instead.
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
  
  /// Adds a prediction observer.
  ///
  /// - Parameter block: The block to execute.
  /// - Returns: An observer.
  func addPredictionObserver(using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: SharedUserDefaults.predictionDidChangeNotification, object: nil, queue: nil, using: block)
  }
  
  /// Removes a prediction observer.
  ///
  /// - Parameter observer: The observer to remove.
  func removePredictionObserver(_ observer: Any) {
    NotificationCenter.default.removeObserver(observer, name: SharedUserDefaults.predictionDidChangeNotification, object: nil)
  }
  
  /// Sets the prediction results and requests a widget reload.
  ///
  /// - Parameters:
  ///   - prediction: The prediction.
  ///   - inWidget: Whether the method is being called from a widget.
  func setCurrentPrediction(_ prediction: PredictionOutput, inWidget: Bool) {
    currentPrediction = prediction
    
    if inWidget {
      NotificationCenter.default.post(name: SharedUserDefaults.predictionDidChangeNotification, object: self)
    }
    else {
      WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.outlookWidgetKind)
    }
  }
  
  /// Sets the current severity and requests a widget reload.
  /// 
  /// - Parameter severity: The current severity.
  func setCurrentSeverity(_ severity: HKCategoryValueSeverity?) {
    currentSeverity = severity
    WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.severityWidgetKind)
    
    if severity == nil {
      WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.outlookWidgetKind)
    }
  }
  
}
