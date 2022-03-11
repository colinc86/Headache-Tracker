//
//  ModelInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Foundation

/// A prediction input.
struct ModelInput {
  
  /// The input date.
  var date: Date
  
  /// The input weather data.
  var weatherStatistics: WeatherStatistics?
  
  /// The input health kit data.
  var healthKitData: [HealthKitData: Double]?
  
  // MARK: Initializers
  
  /// Initializes new model input.
  /// - Parameters:
  ///   - date: <#date description#>
  ///   - weatherStatistics: <#weatherStatistics description#>
  ///   - healthKitData: <#healthKitData description#>
  init(date: Date, weatherStatistics: WeatherStatistics?, healthKitData: [HealthKitData: Double]?) {
    self.date = date
    self.weatherStatistics = weatherStatistics
    self.healthKitData = healthKitData
  }
  
  init(trainingData: TrainingData) {
    self.init(
      date: trainingData.timestamp ?? Date(),
      weatherStatistics: trainingData.weatherStatistics,
      healthKitData: trainingData.healthKitData)
  }
  
  /// The full model input.
  func fullInput() -> InputUnion {
    return InputUnion(providers: [controlledUserInput(), environmentalInput(), chronologicalInput(), uncontrolledUserInput()])
  }
  
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
