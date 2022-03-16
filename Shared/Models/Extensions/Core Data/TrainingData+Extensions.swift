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
      barometricPressure: barometricPressure == 0.0 ? nil : barometricPressure,
      currentPressure: currentPressure == 0.0 ? nil : currentPressure,
      currentHumidity: currentPressure == 0.0 ? nil : currentHumidity,
      currentTemperature: currentPressure == 0.0 ? nil : currentTemperature,
      sigmaPressure: currentPressure == 0.0 ? nil : sigmaPressure,
      sigmaHumidity: currentPressure == 0.0 ? nil : sigmaHumidity,
      sigmaTemperature: currentPressure == 0.0 ? nil : sigmaTemperature)
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
  
  var modelInput: ModelInput {
    ModelInput(
      date: timestamp ?? Date(),
      weatherStatistics: weatherStatistics,
      healthKitData: healthKitData,
      timeIntervalUntilNextHeadacheStart: timeIntervalUntilNextHeadacheStart,
      timeIntervalUntilNextHeadacheEnd: timeIntervalUntilNextHeadacheEnd,
      outlook: outlook ?? .noHeadache,
      severity: severity?.severity ?? .notPresent)
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, input: ModelInput?) {
    self.init(context: context)
    
    logDebug("Creating training data.")
    
    self.timestamp = input?.date
    self.updateWithWeatherStatistics(input?.weatherStatistics)
    self.updateWithHealthKitData(input?.healthKitData)
  }
}
  
// MARK: Public methods
  
extension TrainingData {
  
  /// Updates the training data with the given weather statistics.
  ///
  /// - Parameter weatherStatistics: The weather statistics.
  func updateWithWeatherStatistics(_ weatherStatistics: WeatherStatistics?) {
    if let weatherStatistics = weatherStatistics {
      barometricPressure = weatherStatistics.barometricPressure ?? 0.0
      currentPressure = weatherStatistics.currentPressure ?? 0.0
      currentHumidity = weatherStatistics.currentHumidity ?? 0.0
      currentTemperature = weatherStatistics.currentTemperature ?? 0.0
      sigmaPressure = weatherStatistics.sigmaPressure ?? 0.0
      sigmaHumidity = weatherStatistics.sigmaHumidity ?? 0.0
      sigmaTemperature = weatherStatistics.sigmaTemperature ?? 0.0
      
      // Update the data version if everything went well
      if let currentPressure = weatherStatistics.currentPressure, currentPressure != 0.0 && weatherStatistics.sigmaPressure != nil {
        weatherVersion = Constants.trainingDataWeatherVersion
      }
      else {
        weatherVersion = nil
      }
    }
  }
  
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
  
}
#endif
