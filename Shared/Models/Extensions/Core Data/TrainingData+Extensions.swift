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
      severity: derivedSeverity ?? .notPresent)
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

/// A context-free snapshot of a headache's intervals, used to derive
/// training labels independently of the `severity` relationship.
struct HeadacheEpisode {

  /// A severity value over a time interval.
  struct SeverityInterval {
    let severity: Headache.Severity
    let start: Date
    let end: Date?
  }

  /// The episode's start time.
  let start: Date

  /// The episode's end time, or nil if it's still in progress.
  let end: Date?

  /// The episode's severity progression.
  let severities: [SeverityInterval]

  /// Whether the episode contains the given date.
  ///
  /// - Parameter date: The date.
  /// - Returns: A boolean.
  func contains(_ date: Date) -> Bool {
    return start <= date && date < (end ?? .distantFuture)
  }

  /// The severity at the given date.
  ///
  /// - Parameter date: The date.
  /// - Returns: The severity in effect at the date, or nil when the date is
  ///   outside the episode.
  func severity(at date: Date) -> Headache.Severity? {
    guard contains(date) else {
      return nil
    }
    return severities.last(where: { $0.start <= date && date < ($0.end ?? .distantFuture) })?.severity
  }

}

extension Array where Element == TrainingData {

  /// The rolling window ahead of a sample within which an upcoming headache
  /// counts as a "possible headache" outlook.
  static var possibleHeadacheWindow: TimeInterval { 86400.0 }

  /// Derives the volatile training labels from headache intervals.
  ///
  /// Labels are computed against the full set of episodes rather than the
  /// `severity` relationship, so they survive headache edits and deletions
  /// and use a rolling 24-hour outlook window instead of a calendar-day
  /// boundary.
  ///
  /// - Parameter episodes: The headache episodes to derive labels from.
  func deriveLabels(from episodes: [HeadacheEpisode]) {
    let sortedEpisodes = episodes.sorted(by: { $0.start < $1.start })

    for row in self {
      guard let timestamp = row.timestamp else {
        continue
      }

      if let current = sortedEpisodes.last(where: { $0.contains(timestamp) }) {
        // Inside a headache.
        row.outlook = .headache
        row.derivedSeverity = current.severity(at: timestamp) ?? .unspecified
        row.timeIntervalUntilNextHeadacheStart = nil
        row.timeIntervalUntilNextHeadacheEnd = current.end.map({ $0.timeIntervalSince(timestamp) })
      }
      else {
        // Outside a headache.
        row.derivedSeverity = .notPresent
        row.timeIntervalUntilNextHeadacheEnd = nil

        if let next = sortedEpisodes.first(where: { $0.start > timestamp }) {
          let interval = next.start.timeIntervalSince(timestamp)
          row.timeIntervalUntilNextHeadacheStart = interval
          row.outlook = interval <= Self.possibleHeadacheWindow ? .possibleHeadache : .noHeadache
        }
        else {
          row.timeIntervalUntilNextHeadacheStart = nil
          row.outlook = .noHeadache
        }
      }
    }
  }

}
