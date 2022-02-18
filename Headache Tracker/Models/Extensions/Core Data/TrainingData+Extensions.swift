//
//  TrainingData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import CoreData
import CoreML
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
  
  func classifierInput() -> ModelInput {
    var secondsSinceMidnight = 0.0
    var weekday = 0.0
    if let timestamp = timestamp {
      secondsSinceMidnight = Calendar.current.timeIntervalSinceMidnight(timestamp)
      weekday = Double(Calendar.current.dayOfWeek(timestamp))
    }
    
    return ModelInput(
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
      Weekday: weekday,
      timestamp: timestamp ?? Date(timeIntervalSince1970: 0))
  }
  
}

#if NON_PREVIEW
extension Array where Element == TrainingData {
  
  func batchProvider() -> MLArrayBatchProvider {
    return MLArrayBatchProvider(array: map({ $0.classifierInput() }))
  }
  
  func outlookDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[ModelInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[ModelInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[ModelInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[ModelInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[ModelInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    var outlooks = [String]()
    for i in 0 ..< count {
      // If we're in a headache thn we're done
      if self[i].severity?.headache != nil {
        outlooks.append(OutlookClassifierOutput.headacheOutlook)
        continue
      }
      
      // Get the current timestamp
      guard let timestamp = self[i].timestamp else {
        outlooks.append(OutlookClassifierOutput.noHeadacheOutlook)
        continue
      }
      
      // Is there a headache today?
      if contains(where: { data in
        if data != self[i], let date = data.timestamp {
          return Calendar.current.numberOfDaysBetween(date, and: timestamp) == 0
        }
        return false
      }) {
        outlooks.append(OutlookClassifierOutput.headacheOutlook)
      }
      else {
        outlooks.append(OutlookClassifierOutput.noHeadacheOutlook)
      }
    }
    table[OutlookClassifierOutput.FeatureName.outlook] = outlooks
    return table
  }
  
  func severityDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[ModelInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[ModelInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[ModelInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[ModelInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[ModelInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    table[SeverityClassifierOutput.FeatureName.severity] = map({ ($0.severity?.severity ?? .notPresent).title })
    return table
  }
  
  func onsetTableData() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[ModelInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[ModelInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[ModelInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[ModelInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[ModelInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    var onsets = [Double]()
    for i in 0 ..< count {
      // Are we in a headache?
      if self[i].severity?.headache == nil {
        // We are not in a headache - We need the time of the _next_ headache _today_
        if i < count - 1 {
          var found = false
          for j in i + 1 ..< count {
            guard let startTime = self[j].severity?.headache?.startTime else {
              continue
            }
            
            if Calendar.current.numberOfDaysBetween(startTime, and: self[i].timestamp!) == 0 {
              onsets.append(Calendar.current.timeIntervalSinceMidnight(startTime))
              found = true
              break
            }
            else {
              onsets.append(0.0)
              found = true
              break
            }
          }
          
          if !found {
            onsets.append(0.0)
          }
        }
        else {
          onsets.append(0.0)
        }
      }
      else {
        // We are in a headache
        if let startTime = self[i].severity?.headache?.startTime {
          onsets.append(Calendar.current.timeIntervalSinceMidnight(startTime))
        }
        else {
          onsets.append(0.0)
        }
      }
    }
    table[OnsetRegressorOutput.FeatureName.onset] = onsets
    return table
  }
  
  func durationTableData() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.uvExposure] = map({ $0.uvExposure })
    table[ModelInput.FeatureName.dietaryWater] = map({ $0.dietaryWater })
    table[ModelInput.FeatureName.bloodGlucose] = map({ $0.bloodGlucose })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.bloodPressureSystolic] = map({ $0.bloodPressureSystolic })
    table[ModelInput.FeatureName.bloodPressureDiastolic] = map({ $0.bloodPressureDiastolic })
    table[ModelInput.FeatureName.bodyTemperature] = map({ $0.bodyTemperature })
    table[ModelInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    var durations = [Double]()
    for i in 0 ..< count {
      // Are we in a headache?
      if self[i].severity?.headache == nil {
        // We are not in a headache
        durations.append(0.0)
      }
      else {
        // We are in a headache
        if let duration = self[i].severity?.headache?.duration {
          durations.append(duration)
        }
        else {
          durations.append(0.0)
        }
      }
    }
    table[DurationRegressorOutput.FeatureName.duration] = durations
    return table
  }
  
}
#endif
