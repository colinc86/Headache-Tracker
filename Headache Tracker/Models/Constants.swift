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
  
  struct Identifiers {
    
    /// The identifier to use with background training tasks.
    static let backgroundTrainingTaskIdentifier = ApplicationKey(from: "train")
    
    /// The identifier to use with background prediction tasks.
    static let backgroundPredictionTaskIdentifier = ApplicationKey(from: "predict")
  }
  
  struct AssetKeys {
  
    static let headacheSeverityNotPresent = "HeadacheSeverityNotPresent"
    static let headacheSeverityPresent = "HeadacheSeverityPresent"
    static let headacheSeverityMild = "HeadacheSeverityMild"
    static let headacheSeverityModerate = "HeadacheSeverityModerate"
    static let headacheSeveritySevere = "HeadacheSeveritySevere"
    
  }
}
