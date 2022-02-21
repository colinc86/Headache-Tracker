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
      Respiratory_Rate: respiratoryRate,
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
  
  /// Sets the volitile training variables.
  func setVolitileVariables() {
    for i in 0 ..< count {
      guard let timestamp = self[i].timestamp else {
        continue
      }
      
      if self[i].severity?.headache == nil {
        // Set the time to the next headache start
        if i < count - 1 {
          for j in i + 1 ..< count {
            if let startTime = self[j].severity?.headache?.startTime {
              self[i].timeIntervalUntilNextHeadacheStart = startTime.timeIntervalSince(timestamp)
              break
            }
          }
        }
      }
      else if let endTime = self[i].severity?.headache?.endTime {
        // Set the time to the next headache end
        self[i].timeIntervalUntilNextHeadacheEnd = endTime.timeIntervalSince(timestamp)
      }
    }
  }
  
  /// Returns the training data's batch provider.
  func batchProvider() -> MLArrayBatchProvider {
    return MLArrayBatchProvider(array: map({ $0.classifierInput() }))
  }
  
  /// Uses all training data to create a table that targets the "Outlook" column.
  ///
  /// For every element, if there is a headache that occurs within that same 24-hour
  /// window, then it is marked as "Headache" otherwise "No Headache".
  func outlookDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
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
      // If we're in a headache then we're done
      if self[i].severity?.headache != nil {
        outlooks.append(OutlookClassifierOutput.headacheOutlook)
        continue
      }
      
      // Get the current timestamp
      guard let timestamp = self[i].timestamp else {
        outlooks.append(OutlookClassifierOutput.noHeadacheOutlook)
        continue
      }
      
      // Is there a headache later today?
      if contains(where: { data in
        if let date = data.timestamp, date > timestamp {
          return Calendar.current.numberOfDaysBetween(date, and: timestamp) == 0 && data.severity?.headache != nil
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
  
  /// Uses all training data to create a table that targets the "Severity" column.
  ///
  /// For every element, if it is related to a severity element, then it is set to
  /// that severity, otherwise `notPresent` is used.
  func severityDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
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
  
  /// Only uses training data that is not part of a headache in which a headache
  /// occurs in the same day to target the "Onset" column.
  ///
  /// Each element is set to the time interval until the _next_ headache.
  func onsetTableData() -> [String: MLDataValueConvertible] {
    let filteredData = filter({ $0.timeIntervalUntilNextHeadacheStart != nil })
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = filteredData.map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = filteredData.map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = filteredData.map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = filteredData.map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.respiratoryRate] = filteredData.map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.oxygenSaturation] = filteredData.map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = filteredData.map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = filteredData.map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = filteredData.map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = filteredData.map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = filteredData.map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = filteredData.map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = filteredData.map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = filteredData.map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    table[OnsetRegressorOutput.FeatureName.onset] = filteredData.map({ $0.timeIntervalUntilNextHeadacheStart ?? 0.0 })
    return table
  }
  
  /// Only uses training data that is part of a headache to target the "Duration" column.
  ///
  /// Each element is set to the time interval until the headache's end time.
  func durationTableData() -> [String: MLDataValueConvertible] {
    let filteredData = filter({ $0.timeIntervalUntilNextHeadacheEnd != nil })
    var table = [String: MLDataValueConvertible]()
    table[ModelInput.FeatureName.barometricPressure] = filteredData.map({ $0.barometricPressure })
    table[ModelInput.FeatureName.heartRate] = filteredData.map({ $0.heartRate })
    table[ModelInput.FeatureName.mindfulSession] = filteredData.map({ $0.mindfulSeconds })
    table[ModelInput.FeatureName.sleepAnalysis] = filteredData.map({ $0.sleepSeconds })
    table[ModelInput.FeatureName.respiratoryRate] = filteredData.map({ $0.respiratoryRate })
    table[ModelInput.FeatureName.oxygenSaturation] = filteredData.map({ $0.oxygenSaturation })
    table[ModelInput.FeatureName.heartRateVariability] = filteredData.map({ $0.heartRateVariability })
    table[ModelInput.FeatureName.walkingHeartRateAverage] = filteredData.map({ $0.walkingHeartRateAverage })
    table[ModelInput.FeatureName.restingHeartRate] = filteredData.map({ $0.restingHeartRate })
    table[ModelInput.FeatureName.headphoneAudioExposure] = filteredData.map({ $0.headphoneAudioExposure })
    table[ModelInput.FeatureName.environmentAudioExposure] = filteredData.map({ $0.environmentalAudioExposure })
    table[ModelInput.FeatureName.stepCount] = filteredData.map({ $0.stepCount })
    table[ModelInput.FeatureName.secondsSinceMidnight] = filteredData.map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ModelInput.FeatureName.weekday] = filteredData.map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    table[DurationRegressorOutput.FeatureName.duration] = filteredData.map({ $0.timeIntervalUntilNextHeadacheEnd ?? 0.0 })
    return table
  }
  
}
#endif
