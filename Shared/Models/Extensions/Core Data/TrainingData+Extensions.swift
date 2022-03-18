//
//  TrainingData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/10/22.
//

import CoreData
import CoreLocation
import CoreML
import Foundation

extension TrainingData {
  
  /// The training data's model input.
  var modelInput: ModelInput {
    ModelInput(
      date: timestamp ?? Date(),
      location: location?.location,
      weatherStatistics: weatherData?.weatherStatistics,
      healthKitData: healthData?.healthKitData,
      timeIntervalUntilNextHeadacheStart: timeIntervalUntilNextHeadacheStart,
      timeIntervalUntilNextHeadacheEnd: timeIntervalUntilNextHeadacheEnd,
      outlook: outlook ?? .noHeadache,
      severity: severity?.severity ?? .notPresent)
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, input: ModelInput?) {
    self.init(context: context)
    
    logDebug("Creating training data.")
    updateWithModelInput(input)
  }
}
  
// MARK: Public methods
  
extension TrainingData {
  
  /// Updates the training data with the given model input.
  ///
  /// - Parameter modelInput: The model input.
  func updateWithModelInput(_ modelInput: ModelInput?) {
    timestamp = modelInput?.date
    updateWithLocation(modelInput?.location)
    updateWithWeatherStatistics(modelInput?.weatherStatistics, at: modelInput?.date)
    updateWithHealthKitData(modelInput?.healthKitData, at: modelInput?.date)
  }
  
  /// Updates the location with the given location.
  ///
  /// - Parameter clLocation: The location.
  func updateWithLocation(_ clLocation: CLLocation?) {
    if location == nil, let context = managedObjectContext {
      location = Location(context: context)
    }
    
    location?.updateWithLocation(clLocation)
  }
  
  /// Updates the weather data with the given weather statistics.
  ///
  /// - Parameters:
  ///   - weatherStatistics: The weather statistics.
  ///   - timestamp: The weather statistic's timestamp.
  func updateWithWeatherStatistics(_ weatherStatistics: WeatherStatistics?, at timestamp: Date?) {
    if weatherData == nil, let context = managedObjectContext {
      weatherData = WeatherData(context: context)
    }
    
    weatherData?.updateWithWeatherStatistics(weatherStatistics, at: timestamp)
  }
  
  /// Updates the health data with the given health kit data.
  ///
  /// - Parameters:
  ///   - healthKitData: The health kit data.
  ///   - timestamp: The data's timestamp.
  func updateWithHealthKitData(_ healthKitData: [HealthKitData: Double]?, at timestamp: Date?) {
    if healthData == nil, let context = managedObjectContext {
      healthData = HealthData(context: context)
    }
    
    healthData?.updateWithHealthKitData(healthKitData, at: timestamp)
  }
  
}

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
