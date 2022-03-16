//
//  ModelInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation
import HealthKit

/// A prediction input.
struct ModelInput {
  
  /// The input date.
  var date: Date
  
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
  var severity: HKCategoryValueSeverity
  
  // MARK: Initializers
  
  /// Initializes new model input.
  init(date: Date, weatherStatistics: WeatherStatistics?, healthKitData: [HealthKitData: Double]?, timeIntervalUntilNextHeadacheStart: TimeInterval? = 0.0, timeIntervalUntilNextHeadacheEnd: TimeInterval? = 0.0, outlook: Outlook = .noHeadache, severity: HKCategoryValueSeverity = .notPresent) {
    self.date = date
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
      weatherStatistics: trainingData.weatherStatistics,
      healthKitData: trainingData.healthKitData,
      timeIntervalUntilNextHeadacheStart: trainingData.timeIntervalUntilNextHeadacheStart,
      timeIntervalUntilNextHeadacheEnd: trainingData.timeIntervalUntilNextHeadacheEnd,
      outlook: trainingData.outlook ?? .noHeadache,
      severity: trainingData.severity?.severity ?? .notPresent)
  }
  
  /// The full model input.
  func fullInput() -> InputUnion {
    return InputUnion(providers: [controlledUserInput(), environmentalInput(), chronologicalInput(), uncontrolledUserInput()])
  }
  
  /// A floating point representation of the input.
  ///
  /// - Returns: An array of double values.
  func buffer() -> [Double] {
    let input = fullInput()
    return input.featureNames.map({ input.featureValue(for: $0)?.doubleValue ?? 0.0 })
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
