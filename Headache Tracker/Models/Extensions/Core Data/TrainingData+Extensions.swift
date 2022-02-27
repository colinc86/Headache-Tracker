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
  
  var barometicPressureMeasurement: Measurement<UnitPressure> {
    return Measurement(value: barometricPressure, unit: .kilopascals)
  }
  
  var currentPressureMeasurement: Measurement<UnitPressure> {
    return Measurement(value: currentPressure, unit: .kilopascals)
  }
  
  var currentTemperatureMeasurement: Measurement<UnitTemperature> {
    return Measurement(value: currentTemperature, unit: .celsius)
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, healthKitData: [HealthKitData: Double], weather: Weather?) {
    self.init(context: context)
    
    logDebug("Creating training data.")
    
    self.timestamp = Date()
    self.currentPressure = weather?.currentPressure.converted(to: .kilopascals).value ?? 0.0
    self.currentHumidity = weather?.currentHumidity ?? 0.0
    self.currentTemperature = weather?.currentTemperature.converted(to: .celsius).value ?? 0.0
    self.sigmaPressure = weather?.sigmaPressure ?? 0.0
    self.sigmaHumidity = weather?.sigmaHumidity ?? 0.0
    self.sigmaTemperature = weather?.sigmaTemperature ?? 0.0
    self.barometricPressure = weather?.devicePressure.converted(to: .kilopascals).value ?? 0.0
    
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
      Current_Pressure: currentPressure,
      Current_Humidity: currentHumidity,
      Current_Temperature: currentTemperature,
      Sigma_Pressure: sigmaPressure,
      Sigma_Humidity: sigmaHumidity,
      Sigma_Temperature: sigmaTemperature,
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
    table[ModelInput.FeatureName.currentPressure] = map({ $0.currentPressure })
    table[ModelInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[ModelInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[ModelInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[ModelInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[ModelInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
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
        outlooks.append(Outlook.headache.rawValue)
        continue
      }
      
      // Get the current timestamp
      guard let timestamp = self[i].timestamp else {
        outlooks.append(Outlook.noHeadache.rawValue)
        continue
      }
      
      // Is there a headache later today?
      if contains(where: { data in
        if let date = data.timestamp, date > timestamp {
          return Calendar.current.numberOfDaysBetween(date, and: timestamp) == 0 && data.severity?.headache != nil
        }
        return false
      }) {
        outlooks.append(Outlook.headache.rawValue)
      }
      else {
        outlooks.append(Outlook.noHeadache.rawValue)
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
    table[ModelInput.FeatureName.currentPressure] = map({ $0.currentPressure })
    table[ModelInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[ModelInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[ModelInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[ModelInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[ModelInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
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
    table[ModelInput.FeatureName.currentPressure] = filteredData.map({ $0.currentPressure })
    table[ModelInput.FeatureName.currentHumidity] = filteredData.map({ $0.currentHumidity })
    table[ModelInput.FeatureName.currentTemperature] = filteredData.map({ $0.currentTemperature })
    table[ModelInput.FeatureName.sigmaPressure] = filteredData.map({ $0.sigmaPressure })
    table[ModelInput.FeatureName.sigmaHumidity] = filteredData.map({ $0.sigmaHumidity })
    table[ModelInput.FeatureName.sigmaTemperature] = filteredData.map({ $0.sigmaTemperature })
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
    table[ModelInput.FeatureName.currentPressure] = filteredData.map({ $0.currentPressure })
    table[ModelInput.FeatureName.currentHumidity] = filteredData.map({ $0.currentHumidity })
    table[ModelInput.FeatureName.currentTemperature] = filteredData.map({ $0.currentTemperature })
    table[ModelInput.FeatureName.sigmaPressure] = filteredData.map({ $0.sigmaPressure })
    table[ModelInput.FeatureName.sigmaHumidity] = filteredData.map({ $0.sigmaHumidity })
    table[ModelInput.FeatureName.sigmaTemperature] = filteredData.map({ $0.sigmaTemperature })
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
