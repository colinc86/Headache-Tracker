//
//  TrainingData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import CoreData
import Foundation
import Logger

#if NON_PREVIEW
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
  
  func classifierInput() -> SeverityClassifierInput {
    var secondsSinceMidnight = 0.0
    var weekday = 0.0
    if let timestamp = timestamp {
      secondsSinceMidnight = Calendar.current.timeIntervalSinceMidnight(timestamp)
      weekday = Double(Calendar.current.dayOfWeek(timestamp))
    }
    
    return SeverityClassifierInput(
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

#if NON_PREVIEW
extension Array where Element == TrainingData {
  
  func dataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[SeverityClassifierInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[SeverityClassifierInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[SeverityClassifierInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[SeverityClassifierInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[SeverityClassifierInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[SeverityClassifierInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[SeverityClassifierInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[SeverityClassifierInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[SeverityClassifierInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[SeverityClassifierInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[SeverityClassifierInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[SeverityClassifierInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[SeverityClassifierInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[SeverityClassifierInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[SeverityClassifierInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[SeverityClassifierInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[SeverityClassifierInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[SeverityClassifierInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[SeverityClassifierInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[SeverityClassifierInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    table[SeverityClassifierOutput.FeatureName.severity] = map({ ($0.severity?.severity ?? .notPresent).title })
    return table
  }
  
}
#endif
