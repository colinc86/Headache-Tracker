//
//  TemporalContextTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the temporal-context provider, its medians, and its names.
final class TemporalContextTests: XCTestCase {

  private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

  private func makeInput(health: [HealthKitData: WindowStatistics]? = nil, weather: [WeatherField: WindowStatistics]? = nil) -> ModelInput {
    return ModelInput(
      date: baseDate,
      location: nil,
      weatherStatistics: WeatherStatistics(barometricPressure: nil, currentPressure: 101.0, currentHumidity: 0.5, currentTemperature: 20.0, sigmaPressure: 0.0, sigmaHumidity: 0.0, sigmaTemperature: 0.0),
      healthKitData: [.heartRate: 70.0],
      healthWindowStatistics: health,
      weatherWindowStatistics: weather)
  }

  // MARK: Column names

  func testColumnNamesExtendRawColumnsAndFollowPersonalization() {
    let preferences = Preferences.Predictors()
    let base = TemporalContextInput.columnNames(preferences: preferences, personalized: [])
    XCTAssertTrue(base.contains("Heart Rate 48h Range"))
    XCTAssertTrue(base.contains("Current Pressure 24h Delta"))
    XCTAssertFalse(base.contains("Heart Rate 72h Range"))

    let personalized = TemporalContextInput.columnNames(preferences: preferences, personalized: [.heartRate])
    XCTAssertTrue(personalized.contains("Heart Rate 72h Range"))
    XCTAssertTrue(personalized.contains("Heart Rate 6h Delta"))
    XCTAssertTrue(personalized.contains("Heart Rate 24h Mean"))
    XCTAssertFalse(personalized.contains("Resting Heart Rate 72h Range"))
    XCTAssertEqual(personalized.count, base.count + TemporalContextInput.personalizedStatistics.count)
  }

  func testEveryColumnNameResolvesToItsFeature() {
    for metric in HealthKitData.windowMetrics {
      let feature = CorrelationFeature(healthKitData: metric)
      for statistic in TemporalContextInput.Statistic.allCases {
        let name = TemporalContextInput.featureName(metric, statistic)
        XCTAssertNotNil(name, "\(metric) has no column name")
        XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: name ?? ""), feature, "\(name ?? "") should resolve")
      }
    }
    for field in WeatherField.windowFields {
      for statistic in TemporalContextInput.Statistic.allCases {
        let name = TemporalContextInput.featureName(field, statistic)
        XCTAssertEqual(CorrelationFeature.matching(mlFeatureName: name ?? ""), field.correlationFeature)
      }
    }
    XCTAssertNil(TemporalContextInput.featureName(.menstrualFlowActive, .range48h))
    XCTAssertNil(TemporalContextInput.featureName(.devicePressure, .range48h))
  }

  func testProviderEmitsValuesForItsColumnsOnly() throws {
    let health: [HealthKitData: WindowStatistics] = [.heartRate: WindowStatistics(mean24h: 65.0, delta24h: 5.0, range48h: 30.0, range72h: 35.0, delta6h: 2.0)]
    let provider = TemporalContextInput(health: health, weather: nil, personalized: [])
    XCTAssertEqual(provider.featureValue(for: "Heart Rate 48h Range")?.doubleValue, 30.0)
    XCTAssertEqual(provider.featureValue(for: "Heart Rate 24h Delta")?.doubleValue, 5.0)
    // Not a base column without personalization.
    XCTAssertNil(provider.featureValue(for: "Heart Rate 72h Range"))
    // A column without data reads as the neutral default (imputed upstream).
    XCTAssertEqual(provider.featureValue(for: "Step Count 48h Range")?.doubleValue, 0.0)

    let personalized = TemporalContextInput(health: health, weather: nil, personalized: [.heartRate])
    XCTAssertEqual(personalized.featureValue(for: "Heart Rate 72h Range")?.doubleValue, 35.0)

    // The union sees the new columns.
    var input = makeInput(health: health)
    XCTAssertTrue(input.fullInput().featureNames.contains("Heart Rate 48h Range"))
    input.personalizedFeatures = [.heartRate]
    XCTAssertTrue(input.fullInput().featureNames.contains("Heart Rate 6h Delta"))
  }

  // MARK: Medians

  func testMediansFillMissingWindowStatistics() throws {
    let inputs = [
      makeInput(health: [.heartRate: WindowStatistics(mean24h: 60.0, delta24h: 1.0, range48h: 10.0)], weather: [.humidity: WindowStatistics(range48h: 0.2)]),
      makeInput(health: [.heartRate: WindowStatistics(mean24h: 70.0, delta24h: 3.0, range48h: 20.0)], weather: [.humidity: WindowStatistics(range48h: 0.4)]),
      makeInput(health: [.heartRate: WindowStatistics(mean24h: 80.0, delta24h: 5.0, range48h: 30.0)]),
    ]
    let medians = FeatureMedians.computed(from: inputs)
    XCTAssertEqual(medians.healthWindow[.heartRate]?.mean24h, 70.0)
    XCTAssertEqual(medians.healthWindow[.heartRate]?.range48h, 20.0)
    XCTAssertNil(medians.healthWindow[.heartRate]?.range72h, "never present → no median")
    XCTAssertEqual(try XCTUnwrap(medians.weatherWindow[.humidity]?.range48h), 0.3, accuracy: 1e-12)
    XCTAssertNil(medians.healthWindow[.stepCount])

    // A row lacking the metric entirely gets the full median entry; a row
    // with a partial entry keeps its own values.
    let empty = medians.imputing(makeInput())
    XCTAssertEqual(empty.healthWindowStatistics?[.heartRate]?.mean24h, 70.0)
    XCTAssertEqual(try XCTUnwrap(empty.weatherWindowStatistics?[.humidity]?.range48h), 0.3, accuracy: 1e-12)
    let partial = medians.imputing(makeInput(health: [.heartRate: WindowStatistics(range48h: 99.0)]))
    XCTAssertEqual(partial.healthWindowStatistics?[.heartRate]?.range48h, 99.0)
    XCTAssertEqual(partial.healthWindowStatistics?[.heartRate]?.mean24h, 70.0)

    // The sidecar round-trips, and an old sidecar without the keys decodes.
    let data = try JSONEncoder().encode(medians)
    let decoded = try JSONDecoder().decode(FeatureMedians.self, from: data)
    XCTAssertEqual(decoded.healthWindow[.heartRate], medians.healthWindow[.heartRate])
    let old = try JSONDecoder().decode(FeatureMedians.self, from: Data("{\"healthKit\":[],\"pressure\":101.0}".utf8))
    XCTAssertEqual(old.pressure, 101.0)
    XCTAssertTrue(old.healthWindow.isEmpty)
  }

  // MARK: What-if coherence

  func testSettingValueRederivesDeltasAndNeutralizingUsesMedians() {
    let health: [HealthKitData: WindowStatistics] = [.heartRate: WindowStatistics(mean24h: 65.0, delta24h: 5.0, range48h: 30.0, range72h: 35.0, delta6h: 2.0)]
    let input = makeInput(health: health)

    let raised = input.settingValue(80.0, for: .health(.heartRate))
    XCTAssertEqual(raised.healthWindowStatistics?[.heartRate]?.delta24h, 15.0)
    XCTAssertEqual(raised.healthWindowStatistics?[.heartRate]?.range48h, 30.0, "history is unchanged")
    XCTAssertNotNil(raised.healthWindowStatistics?[.heartRate]?.delta6h)

    var medians = FeatureMedians()
    medians.healthKit[.heartRate] = 62.0
    medians.healthWindow[.heartRate] = WindowStatistics(mean24h: 62.0, delta24h: 0.0, range48h: 12.0)
    let neutral = input.neutralizing(.health(.heartRate), medians: medians)
    XCTAssertEqual(neutral.healthKitData?[.heartRate], 62.0)
    XCTAssertEqual(neutral.healthWindowStatistics?[.heartRate]?.range48h, 12.0)
    XCTAssertEqual(neutral.healthWindowStatistics?[.heartRate]?.delta24h, 0.0)
  }

}
