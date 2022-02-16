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
    static let backgroundTrainingTaskIdentifier = ApplicationKey(from: "train")
    static let backgroundPredictionTaskIdentifier = ApplicationKey(from: "predict")
  }
}
