//
//  TrainingData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import CoreData
import CoreML
import Foundation

#if NON_PREVIEW
import CreateML
#endif

extension TrainingData {
  
  var devicePressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: barometricPressure, unit: .kilopascals)
  }
  
  var pressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: currentPressure, unit: .kilopascals)
  }
  
  var humidityMeasurement: Measurement<UnitRate> {
    Measurement(value: currentHumidity, unit: .decimal)
  }
  
  var temperatureMeasurement: Measurement<UnitTemperature> {
    Measurement(value: currentTemperature, unit: .celsius)
  }
  
  var weatherStatistics: WeatherStatistics {
    WeatherStatistics(
      barometricPressure: barometricPressure,
      currentPressure: currentPressure,
      currentHumidity: currentHumidity,
      currentTemperature: currentTemperature,
      sigmaPressure: sigmaPressure,
      sigmaHumidity: sigmaHumidity,
      sigmaTemperature: sigmaTemperature)
  }
  
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
  
  convenience init(context: NSManagedObjectContext, input: ModelInput?) {
    self.init(context: context)
    
    logDebug("Creating training data.")
    
    self.timestamp = input?.date
    self.barometricPressure = input?.weatherStatistics?.barometricPressure ?? 0.0
    self.currentPressure = input?.weatherStatistics?.currentPressure ?? 0.0
    self.currentHumidity = input?.weatherStatistics?.currentHumidity ?? 0.0
    self.currentTemperature = input?.weatherStatistics?.currentTemperature ?? 0.0
    self.sigmaPressure = input?.weatherStatistics?.sigmaPressure ?? 0.0
    self.sigmaHumidity = input?.weatherStatistics?.sigmaHumidity ?? 0.0
    self.sigmaTemperature = input?.weatherStatistics?.sigmaTemperature ?? 0.0
    self.updateWithHealthKitData(input?.healthKitData)
  }
}
  
// MARK: Public methods
  
extension TrainingData {
  
  /// Updates the training data with the given health kit data.
  ///
  /// - Parameter healthKitData: The health kit data.
  func updateWithHealthKitData(_ healthKitData: [HealthKitData: Double]?) {
    if let healthKitData = healthKitData {
      for (key, value) in healthKitData {
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
      
      // Update the data version
      version = Constants.trainingDataVersion
    }
  }
  
}

#if NON_PREVIEW
extension Array where Element == TrainingData {
  
  /// Sets the volitile training variables.
  func setVolitileVariables() {
    for i in 0 ..< count {
      // Handle start and end times and outlook
      guard let timestamp = self[i].timestamp else {
        continue
      }
      
      if self[i].severity?.headache == nil {
        // Set the time to the next headache start
        if i < count - 1 {
          for j in i + 1 ..< count {
            if let startTime = self[j].severity?.headache?.startTime {
              let interval = startTime.timeIntervalSince(timestamp)
              self[i].timeIntervalUntilNextHeadacheStart = interval
              
              // Is the headache today?
              if Calendar.current.numberOfDaysBetween(timestamp, and: startTime) == 0 {
                self[i].outlook = .possibleHeadache
              }
              else {
                self[i].outlook = .noHeadache
              }
              break
            }
          }
        }
      }
      else if let endTime = self[i].severity?.headache?.endTime {
        // Set the time to the next headache end
        self[i].timeIntervalUntilNextHeadacheEnd = endTime.timeIntervalSince(timestamp)
        self[i].outlook = .headache
      }
    }
  }
  
  /// Uses all training data to create a table that targets the "Outlook" column.
  ///
  /// For every element, if there is a headache that occurs within that same 24-hour
  /// window, then it is marked as "Headache" otherwise "No Headache".
  func outlookDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    
    // Environmental input
    table[EnvironmentalInput.FeatureName.currentPressure] = map({ $0.barometricPressure > 0.0 ? $0.barometricPressure : $0.currentPressure })
    table[EnvironmentalInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[EnvironmentalInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[EnvironmentalInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[EnvironmentalInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[EnvironmentalInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
    table[EnvironmentalInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    
    // Time input
    table[ChronologicalInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ChronologicalInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    // Uncontrolled input
    table[UncontrolledUserInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[UncontrolledUserInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[UncontrolledUserInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[UncontrolledUserInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[UncontrolledUserInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[UncontrolledUserInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    
    // Controlled input
    table[ControlledUserInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ControlledUserInput.FeatureName.sleepSeconds] = map({ $0.sleepSeconds })
    table[ControlledUserInput.FeatureName.sleepOnset] = map({ $0.sleepOnset })
    table[ControlledUserInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ControlledUserInput.FeatureName.stepCount] = map({ $0.stepCount })
    
    // Output
    table[OutlookClassifierOutput.FeatureName.outlook] = map({ ($0.outlook ?? .noHeadache).rawValue })
    return table
  }
  
  /// Uses all training data to create a table that targets the "Severity" column.
  ///
  /// For every element, if it is related to a severity element, then it is set to
  /// that severity, otherwise `notPresent` is used.
  func severityDataTable() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    
    // Environmental input
    table[EnvironmentalInput.FeatureName.currentPressure] = map({ $0.barometricPressure > 0.0 ? $0.barometricPressure : $0.currentPressure })
    table[EnvironmentalInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[EnvironmentalInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[EnvironmentalInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[EnvironmentalInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[EnvironmentalInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
    table[EnvironmentalInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    
    // Time input
    table[ChronologicalInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ChronologicalInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    // Uncontrolled input
    table[UncontrolledUserInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[UncontrolledUserInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[UncontrolledUserInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[UncontrolledUserInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[UncontrolledUserInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[UncontrolledUserInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    
    // Controlled input
    table[ControlledUserInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ControlledUserInput.FeatureName.sleepSeconds] = map({ $0.sleepSeconds })
    table[ControlledUserInput.FeatureName.sleepOnset] = map({ $0.sleepOnset })
    table[ControlledUserInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ControlledUserInput.FeatureName.stepCount] = map({ $0.stepCount })
    
    // Output
    table[SeverityClassifierOutput.FeatureName.severity] = map({ ($0.severity?.severity ?? .notPresent).title })
    return table
  }
  
  /// Only uses training data that is not part of a headache in which a headache
  /// occurs in the same day to target the "Onset" column.
  ///
  /// Each element is set to the time interval until the _next_ headache.
  func onsetTableData() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    
    // Environmental input
    table[EnvironmentalInput.FeatureName.currentPressure] = map({ $0.barometricPressure > 0.0 ? $0.barometricPressure : $0.currentPressure })
    table[EnvironmentalInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[EnvironmentalInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[EnvironmentalInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[EnvironmentalInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[EnvironmentalInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
    table[EnvironmentalInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    
    // Time input
    table[ChronologicalInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ChronologicalInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    // Uncontrolled input
    table[UncontrolledUserInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[UncontrolledUserInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[UncontrolledUserInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[UncontrolledUserInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[UncontrolledUserInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[UncontrolledUserInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    
    // Controlled input
    table[ControlledUserInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ControlledUserInput.FeatureName.sleepSeconds] = map({ $0.sleepSeconds })
    table[ControlledUserInput.FeatureName.sleepOnset] = map({ $0.sleepOnset })
    table[ControlledUserInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ControlledUserInput.FeatureName.stepCount] = map({ $0.stepCount })
    
    // Output
    table[OnsetRegressorOutput.FeatureName.onset] = map({ $0.timeIntervalUntilNextHeadacheStart ?? 0.0 })
    return table
  }
  
  /// Only uses training data that is part of a headache to target the "Duration" column.
  ///
  /// Each element is set to the time interval until the headache's end time.
  func durationTableData() -> [String: MLDataValueConvertible] {
    var table = [String: MLDataValueConvertible]()
    
    // Environmental input
    table[EnvironmentalInput.FeatureName.currentPressure] = map({ $0.barometricPressure > 0.0 ? $0.barometricPressure : $0.currentPressure })
    table[EnvironmentalInput.FeatureName.currentHumidity] = map({ $0.currentHumidity })
    table[EnvironmentalInput.FeatureName.currentTemperature] = map({ $0.currentTemperature })
    table[EnvironmentalInput.FeatureName.sigmaPressure] = map({ $0.sigmaPressure })
    table[EnvironmentalInput.FeatureName.sigmaHumidity] = map({ $0.sigmaHumidity })
    table[EnvironmentalInput.FeatureName.sigmaTemperature] = map({ $0.sigmaTemperature })
    table[EnvironmentalInput.FeatureName.environmentAudioExposure] = map({ $0.environmentalAudioExposure })
    
    // Time input
    table[ChronologicalInput.FeatureName.secondsSinceMidnight] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.timeIntervalSinceMidnight(timestamp))
      }
      return Double(0.0)
    })
    table[ChronologicalInput.FeatureName.weekday] = map({ data -> Double in
      if let timestamp = data.timestamp {
        return Double(Calendar.current.dayOfWeek(timestamp))
      }
      return Double(0.0)
    })
    
    // Uncontrolled input
    table[UncontrolledUserInput.FeatureName.heartRate] = map({ $0.heartRate })
    table[UncontrolledUserInput.FeatureName.respiratoryRate] = map({ $0.respiratoryRate })
    table[UncontrolledUserInput.FeatureName.oxygenSaturation] = map({ $0.oxygenSaturation })
    table[UncontrolledUserInput.FeatureName.heartRateVariability] = map({ $0.heartRateVariability })
    table[UncontrolledUserInput.FeatureName.walkingHeartRateAverage] = map({ $0.walkingHeartRateAverage })
    table[UncontrolledUserInput.FeatureName.restingHeartRate] = map({ $0.restingHeartRate })
    
    // Controlled input
    table[ControlledUserInput.FeatureName.mindfulSession] = map({ $0.mindfulSeconds })
    table[ControlledUserInput.FeatureName.sleepSeconds] = map({ $0.sleepSeconds })
    table[ControlledUserInput.FeatureName.sleepOnset] = map({ $0.sleepOnset })
    table[ControlledUserInput.FeatureName.headphoneAudioExposure] = map({ $0.headphoneAudioExposure })
    table[ControlledUserInput.FeatureName.stepCount] = map({ $0.stepCount })
    
    // Output
    table[DurationRegressorOutput.FeatureName.duration] = map({ $0.timeIntervalUntilNextHeadacheEnd ?? 0.0 })
    return table
  }
  
}
#endif
