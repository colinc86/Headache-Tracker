//
//  HealthData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import CoreData
import Foundation

extension HealthData {
  
  /// The health kit data.
  var healthKitData: [HealthKitData: Double] {
    return [
      .heartRate: heartRate,
      .mindfulSession: mindfulSeconds,
      .sleepSeconds: sleepSeconds,
      .sleepOnset: sleepOnset,
      .respiratoryRate: respiratoryRate,
      .oxygenSaturation: oxygenSaturation,
      .heartRateVariabilitySDNN: heartRateVariability,
      .walkingHeartRateAverage: walkingHeartRateAverage,
      .restingHeartRate: restingHeartRate,
      .headphoneAudioExposure: headphoneAudioExposure,
      .environmentalAudioExposure: environmentalAudioExposure,
      .stepCount: stepCount
    ]
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, timestamp: Date?, data: [HealthKitData: Double]?) {
    self.init(context: context)
    updateWithHealthKitData(data, at: timestamp)
  }
  
}

// MARK: Public methods

extension HealthData {
  
  /// Updates the health data with the given health kit data.
  ///
  /// - Parameters:
  ///   - healthKitData: The health kit data.
  ///   - timestamp: The data's timestamp.
  func updateWithHealthKitData(_ data: [HealthKitData: Double]?, at timestamp: Date?) {
    if let data = data {
      for (key, value) in data {
        switch key {
        case .heartRate: heartRate = value
        case .mindfulSession: mindfulSeconds = value
        case .sleepSeconds: sleepSeconds = value
        case .sleepOnset: sleepOnset = value
        case .respiratoryRate: respiratoryRate = value
        case .oxygenSaturation: oxygenSaturation = value
        case .heartRateVariabilitySDNN: heartRateVariability = value
        case .walkingHeartRateAverage: walkingHeartRateAverage = value
        case .restingHeartRate: restingHeartRate = value
        case .headphoneAudioExposure: headphoneAudioExposure = value
        case .environmentalAudioExposure: environmentalAudioExposure = value
        case .stepCount: stepCount = value
        default: continue
        }
      }
      
      // Update the data version and timestamp
      self.timestamp = timestamp
      version = Constants.trainingDataVersion
    }
    else {
      self.timestamp = nil
      version = nil
      heartRate = 0.0
      mindfulSeconds = 0.0
      sleepSeconds = 0.0
      sleepOnset = 0.0
      respiratoryRate = 0.0
      oxygenSaturation = 0.0
      heartRateVariability = 0.0
      walkingHeartRateAverage = 0.0
      restingHeartRate = 0.0
      headphoneAudioExposure = 0.0
      environmentalAudioExposure = 0.0
      stepCount = 0.0
    }
  }
  
}
