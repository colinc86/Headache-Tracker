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
  static let trainingDataVersion = "1.1"
  
  /// The weather training data version.
  static let trainingDataWeatherVersion = "1.1"

  /// The minimum number of training data samples required before the first
  /// models are trained.
  static let minimumTrainingDataCount = 50
  
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
    
    /// The identifier to use with daily outlook tasks.
    static let backgroundOutlookTaskIdentifier = ApplicationKey(from: "outlook")
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
