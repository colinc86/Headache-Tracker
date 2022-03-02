//
//  Constants.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/15/22.
//

import ApplicationKey
import Foundation

struct Constants {
  
  /// The desired time between predictions.
  static let backgroundPredictionInterval: TimeInterval = 3600.0
  
  /// The minimum refresh interval.
  static let predictionRefreshInterval: TimeInterval = 600.0
  
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
  
  struct Identifiers {
    
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
  
  struct WeatherAPI {
    
    /// The weather API username.
    static let username = "f6fad9695be5449475ccfba804ec1018"
    
    /// The weather API password.
    static let password = "c4efa0b907f057cdb110d36651e442b3"
    
  }
  
}
