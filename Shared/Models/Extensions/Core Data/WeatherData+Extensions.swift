//
//  WeatherData+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import CoreData
import Foundation

extension WeatherData {
  
  /// The device pressure measurement in kilopascals.
  var devicePressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: devicePressure, unit: .kilopascals)
  }
  
  /// The weather pressure measurement in kilopascals.
  var pressureMeasurement: Measurement<UnitPressure> {
    Measurement(value: pressure, unit: .kilopascals)
  }
  
  /// The weather humidity measurement as a decimal.
  var humidityMeasurement: Measurement<UnitRate> {
    Measurement(value: humidity, unit: .decimal)
  }
  
  /// The weather temperature measurement in celsius.
  var temperatureMeasurement: Measurement<UnitTemperature> {
    Measurement(value: temperature, unit: .celsius)
  }
  
  /// The weather data's weather statistics.
  var weatherStatistics: WeatherStatistics {
    WeatherStatistics(
      barometricPressure: devicePressure == 0.0 ? nil : devicePressure,
      currentPressure: pressure,
      currentHumidity: humidity,
      currentTemperature: temperature,
      sigmaPressure: sigmaPressure,
      sigmaHumidity: sigmaHumidity,
      sigmaTemperature: sigmaTemperature)
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, timestamp: Date?, weatherStatistics: WeatherStatistics?) {
    self.init(context: context)
    updateWithWeatherStatistics(weatherStatistics, at: timestamp)
  }
  
}

// MARK: Public methods

extension WeatherData {
  
  /// Updates the weather data with the given weather statistics.
  ///
  /// - Parameters:
  ///   - weatherStatistics: The weather statistics.
  ///   - timestamp: The weather statistic's timestamp.
  func updateWithWeatherStatistics(_ weatherStatistics: WeatherStatistics?, at timestamp: Date?) {
    if let weatherStatistics = weatherStatistics {
      devicePressure = weatherStatistics.barometricPressure ?? 0.0
      pressure = weatherStatistics.currentPressure
      humidity = weatherStatistics.currentHumidity
      temperature = weatherStatistics.currentTemperature
      sigmaPressure = weatherStatistics.sigmaPressure
      sigmaHumidity = weatherStatistics.sigmaHumidity
      sigmaTemperature = weatherStatistics.sigmaTemperature
      
      // Update the data version if everything went well
      self.timestamp = timestamp
      version = Constants.trainingDataWeatherVersion
    }
    else {
      self.timestamp = nil
      version = nil
      devicePressure = 0.0
      pressure = 0.0
      humidity = 0.0
      temperature = 0.0
      sigmaPressure = 0.0
      sigmaHumidity = 0.0
      sigmaTemperature = 0.0
    }
  }
  
}
