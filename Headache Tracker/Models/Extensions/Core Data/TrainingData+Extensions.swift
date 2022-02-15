//
//  TrainingData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import CoreData
import Foundation
import Logger

#if !DEBUG
import CreateML
#endif

extension TrainingData {
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, healthKitData: [HealthKitData: Double], barometricPressure: Double) {
    self.init(context: context)
    
    logDebug("Creating training data with barometric pressure \(barometricPressure) and data \(healthKitData)")
    
    self.timestamp = Date()
    self.barometricPressure = barometricPressure
    
    for (key, value) in healthKitData {
      switch key {
      case .heartRate: heartRate = value
      case .mindfulSession: mindfulSeconds = value
      case .sleepAnalysis: sleepSeconds = value
      case .uvExposure: uvExposure = value
      case .dietaryWater: dietaryWater = value
      case .bloodGlucose: bloodGlucose = value
      case .respiratoryRate: respiratoryRate = value
      case .bloodPressureSystolic: bloodPressureSystolic = value
      case .bloodPressureDiastolic: bloodPressureDiastolic = value
      case .bodyTemperature: bodyTemperature = value
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
  }
  
  func classifierInput() -> HeadacheClassifierInput {
    var secondsSinceMidnight = 0.0
    var weekday = 0.0
    if let timestamp = timestamp {
      secondsSinceMidnight = Calendar.current.timeIntervalSinceMidnight(timestamp)
      weekday = Double(Calendar.current.dayOfWeek(timestamp))
    }
    
    return HeadacheClassifierInput(
      Barometric_Pressure: barometricPressure,
      Heart_Rate: heartRate,
      Mindful_Session: mindfulSeconds,
      Sleep_Analysis: sleepSeconds,
      UV_Exposure: uvExposure,
      Dietary_Water: dietaryWater,
      Blood_Glucose: bloodGlucose,
      Respiratory_Rate: respiratoryRate,
      Blood_Prerssure_Systolic: bloodPressureSystolic,
      Blood_Prerssure_Diastolic: bloodPressureDiastolic,
      Body_Temperature: bodyTemperature,
      Oxygen_Saturation: oxygenSaturation,
      Heart_Rate_Variability: heartRateVariability,
      Walking_Heart_Rate_Average: walkingHeartRateAverage,
      Resting_Heart_Rate: restingHeartRate,
      Headphone_Audio_Exposure: headphoneAudioExposure,
      Environment_Audio_Exposure: environmentalAudioExposure,
      Step_Count: stepCount,
      Seconds_Since_Midnight: secondsSinceMidnight,
      Weekday: weekday)
  }
  
}

#if !DEBUG
extension Array where Element == TrainingData {
  
  func dataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[HeadacheClassifierInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[HeadacheClassifierInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[HeadacheClassifierInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[HeadacheClassifierInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[HeadacheClassifierInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[HeadacheClassifierInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[HeadacheClassifierInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[HeadacheClassifierInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[HeadacheClassifierInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[HeadacheClassifierInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[HeadacheClassifierInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[HeadacheClassifierInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[HeadacheClassifierInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[HeadacheClassifierInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[HeadacheClassifierInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[HeadacheClassifierInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[HeadacheClassifierInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[HeadacheClassifierInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[HeadacheClassifierInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[HeadacheClassifierInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    table[HeadacheClassifierOutput.FeatureName.severity] = map({ ($0.severity?.severity ?? .notPresent).title })
    return table
  }
  
}
#endif
