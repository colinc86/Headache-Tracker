//
//  Constants.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/15/22.
//

import ApplicationKey
import Foundation

struct Constants {
  
  /// The current training data version.
  ///
  /// 1.2: per-metric sampling windows, sleep stages, HRV in milliseconds,
  /// presence bits, and sleep onset as a date.
  /// 1.3: dietary caffeine and water, time in daylight, exercise minutes,
  /// and menstrual cycle features.
  static let trainingDataVersion = "1.3"
  
  /// The weather training data version.
  static let trainingDataWeatherVersion = "1.1"

  /// The minimum number of training data samples required before the first
  /// models are trained.
  static let minimumTrainingDataCount = 50

  /// The model feature schema version. Bump when the feature set changes
  /// (renamed/added/removed features), which invalidates compiled models
  /// and stored evaluations; a launch-time check resets both.
  static let modelSchemaVersion = 3

  /// The defaults key storing the last seen model schema version.
  static let modelSchemaVersionKey = "modelSchemaVersion"
  
  /// The application's app group identifier.
  static let appGroupIdentifier = "group.com.cnc.Headache-Tracker.contents"
  
  struct AssetKeys {
    
    static let headacheSeverityNotPresent = "HeadacheSeverityNotPresent"
    static let headacheSeverityPresent = "HeadacheSeverityPresent"
    static let headacheSeverityMild = "HeadacheSeverityMild"
    static let headacheSeverityModerate = "HeadacheSeverityModerate"
    static let headacheSeveritySevere = "HeadacheSeveritySevere"
    
  }
  
  struct Bugfender {
    
    /// The Bugfender API key.
    static let apiKey = "EympFu86jcLlhHeq78zP5JouXlWE16Qu"

  }
  
  struct CoreData {
    
    /// The application's coredata store name.
    static let sqliteContainerName = "Headache_Tracker"
    
    /// The application's backup coredata store name.
    static let sqliteBackupContainerName = "Headache_Tracker_Backup"
    
  }
  
  struct Tasks {
    
    /// The desired time between predictions.
    static let backgroundPredictionInterval: TimeInterval = 3600.0
    
    /// The minimum refresh interval.
    static let predictionRefreshInterval: TimeInterval = 600.0
    
    /// The identifier to use with background training tasks.
    static let backgroundTrainingTaskIdentifier = ApplicationKey(from: "train")
    
    /// The identifier to use with background prediction tasks.
    static let backgroundPredictionTaskIdentifier = ApplicationKey(from: "predict")
  }
  
  struct URLSchemes {
    
    static let scheme = "myheadache"
    static let severityHost = "severity"
    static let rawValueQuery = "rawValue"
    
  }
  
  struct Widgets {
    
    /// The outlook widget's kind.
    static let outlookWidgetKind = "com.cnc.myheadache.widget.outlook"
    
    /// The severity widget's kind.
    static let severityWidgetKind = "com.cnc.myheadache.widget.severity"
    
  }
  
}
