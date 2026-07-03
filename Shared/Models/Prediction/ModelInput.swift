//
//  ModelInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import CoreLocation
import Foundation

/// A prediction input.
struct ModelInput: Codable {
  
  enum CodingKeys: CodingKey {
    case date
    case weatherStatistics
    case healthKitData
    case outlook
    case severity
  }
  
  static let empty = ModelInput(date: Date(), location: nil, weatherStatistics: nil, healthKitData: nil, timeIntervalUntilNextHeadacheStart: nil, timeIntervalUntilNextHeadacheEnd: nil, outlook: .noHeadache, severity: .notPresent)
  
  /// The input date.
  var date: Date
  
  /// The location of the weather data.
  var location: CLLocation?
  
  /// The input weather data.
  var weatherStatistics: WeatherStatistics?
  
  /// The input health kit data.
  var healthKitData: [HealthKitData: Double]?
  
  /// The time interval until the next headache begins.
  var timeIntervalUntilNextHeadacheStart: TimeInterval?
  
  /// The time interval until the current headache ends.
  var timeIntervalUntilNextHeadacheEnd: TimeInterval?
  
  /// The input's outlook.
  var outlook: Outlook
  
  /// The input's severity.
  var severity: Headache.Severity
  
  // MARK: Initializers
  
  /// Initializes new model input.
  init(date: Date, location: CLLocation?, weatherStatistics: WeatherStatistics?, healthKitData: [HealthKitData: Double]?, timeIntervalUntilNextHeadacheStart: TimeInterval? = 0.0, timeIntervalUntilNextHeadacheEnd: TimeInterval? = 0.0, outlook: Outlook = .noHeadache, severity: Headache.Severity = .notPresent) {
    self.date = date
    self.location = location
    self.weatherStatistics = weatherStatistics
    self.healthKitData = healthKitData
    self.timeIntervalUntilNextHeadacheStart = timeIntervalUntilNextHeadacheStart
    self.timeIntervalUntilNextHeadacheEnd = timeIntervalUntilNextHeadacheEnd
    self.outlook = outlook
    self.severity = severity
  }
  
  /// Initializes new model input.
  ///
  /// - Parameter trainingData: The input's training data.
  init(trainingData: TrainingData) {
    self.init(
      date: trainingData.timestamp ?? Date(),
      location: trainingData.location?.location,
      weatherStatistics: trainingData.weatherData?.weatherStatistics,
      healthKitData: trainingData.healthData?.healthKitData,
      timeIntervalUntilNextHeadacheStart: trainingData.timeIntervalUntilNextHeadacheStart,
      timeIntervalUntilNextHeadacheEnd: trainingData.timeIntervalUntilNextHeadacheEnd,
      outlook: trainingData.outlook ?? .noHeadache,
      severity: trainingData.severity?.severity ?? .notPresent)
  }
  
  /// The full model input.
  func fullInput() -> InputUnion {
    return InputUnion(providers: [controlledUserInput(), environmentalInput(), chronologicalInput(), uncontrolledUserInput()])
  }

}

// MARK: Private methods

extension ModelInput {
  
  private func controlledUserInput() -> ControlledUserInput {
    return ControlledUserInput(healthKitData: healthKitData)
  }
  
  private func environmentalInput() -> EnvironmentalInput {
    return EnvironmentalInput(weatherStatistics: weatherStatistics, healthKitData: healthKitData)
  }
  
  private func chronologicalInput() -> ChronologicalInput {
    return ChronologicalInput(date: date)
  }
  
  private func uncontrolledUserInput() -> UncontrolledUserInput {
    return UncontrolledUserInput(healthKitData: healthKitData)
  }
  
}
