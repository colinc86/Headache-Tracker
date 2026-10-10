//
//  SamplingAndStorageTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 9/30/26.
//

import CoreData
import DataController
import XCTest
@testable import Headache_Tracker

/// Tests for model 2.5 storage: training-row sources and dedupe, window
/// context round-trips, evaluation outcomes, and the store migration.
final class SamplingAndStorageTests: XCTestCase {

  private var dataController: DataController!

  private var context: NSManagedObjectContext {
    return dataController.container.viewContext
  }

  override func setUpWithError() throws {
    dataController = DataController(containerName: "Headache_Tracker", inMemory: true)
  }

  override func tearDownWithError() throws {
    dataController = nil
  }

  private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

  private func makeInput(at date: Date) -> ModelInput {
    return ModelInput(date: date, location: nil, weatherStatistics: nil, healthKitData: [.heartRate: 70.0])
  }

  // MARK: Sources and dedupe

  func testSourceKindRoundTrips() throws {
    let row = TrainingData(context: context, input: makeInput(at: baseDate))
    XCTAssertEqual(row.sourceKind, .unknown)
    row.sourceKind = .background
    try context.save()
    XCTAssertEqual(row.source, TrainingDataSource.background.rawValue)
    XCTAssertEqual(row.sourceKind, .background)
    XCTAssertEqual(TrainingDataSource.allCases.count, 5)
  }

  func testRowExistsHonoursTolerance() throws {
    _ = TrainingData(context: context, input: makeInput(at: baseDate))
    try context.save()

    XCTAssertTrue(try TrainingData.rowExists(near: baseDate.addingTimeInterval(600.0), within: 1800.0, in: context))
    XCTAssertTrue(try TrainingData.rowExists(near: baseDate.addingTimeInterval(-1799.0), within: 1800.0, in: context))
    XCTAssertFalse(try TrainingData.rowExists(near: baseDate.addingTimeInterval(1801.0), within: 1800.0, in: context))
    XCTAssertFalse(try TrainingData.rowExists(near: baseDate.addingTimeInterval(-86400.0), within: 1800.0, in: context))
  }

  func testRowExistsIsFalseOnEmptyStore() throws {
    XCTAssertFalse(try TrainingData.rowExists(near: baseDate, within: 1800.0, in: context))
  }

  // MARK: Window context

  func testContextDataRoundTripsPresentMetricsOnly() throws {
    var health = [HealthKitData: WindowStatistics]()
    health[.heartRate] = WindowStatistics(mean24h: 65.0, delta24h: 5.0, range48h: 30.0, range72h: 35.0, delta6h: 2.0)
    health[.stepCount] = WindowStatistics(mean24h: 400.0, delta24h: -100.0, range48h: nil, range72h: nil, delta6h: nil)
    health[.wristTemperature] = WindowStatistics(mean24h: nil, delta24h: nil, range48h: 0.4, range72h: 0.6, delta6h: nil)
    let weather: [WeatherField: WindowStatistics] = [
      .currentPressure: WindowStatistics(mean24h: 101.2, delta24h: -0.3, range48h: 1.1, range72h: 1.4, delta6h: -0.1),
    ]

    var input = makeInput(at: baseDate)
    input.healthWindowStatistics = health
    input.weatherWindowStatistics = weather
    let row = TrainingData(context: context, input: input)
    try context.save()

    let stored = try XCTUnwrap(row.contextData)
    XCTAssertEqual(stored.healthVersion, Constants.trainingDataContextVersion)
    XCTAssertEqual(stored.weatherVersion, Constants.trainingDataContextVersion)
    XCTAssertEqual(stored.timestamp, baseDate)

    let readHealth = stored.healthWindowStatistics
    XCTAssertEqual(readHealth.count, 3)
    XCTAssertEqual(readHealth[.heartRate], health[.heartRate])
    XCTAssertEqual(readHealth[.stepCount], health[.stepCount])
    XCTAssertEqual(readHealth[.wristTemperature], health[.wristTemperature])
    // A metric that was never written is absent, not zero.
    XCTAssertNil(readHealth[.respiratoryRate])
    XCTAssertEqual(stored.weatherWindowStatistics, weather)

    // The rebuilt model input carries the same context.
    XCTAssertEqual(row.modelInput.healthWindowStatistics, health)
    XCTAssertEqual(row.modelInput.weatherWindowStatistics, weather)
  }

  func testContextDataRecordsAbsenceAsNilVersion() throws {
    let row = TrainingData(context: context, input: makeInput(at: baseDate))
    let stored = try XCTUnwrap(row.contextData)
    XCTAssertNil(stored.healthVersion)
    XCTAssertNil(stored.weatherVersion)
    XCTAssertTrue(stored.healthWindowStatistics.isEmpty)
    XCTAssertTrue(stored.weatherWindowStatistics.isEmpty)

    // A later update with data stamps the version and clears stale bits.
    row.updateWithWindowStatistics(health: [.heartRate: WindowStatistics(mean24h: 60.0)], weather: nil, at: baseDate)
    XCTAssertEqual(stored.healthVersion, Constants.trainingDataContextVersion)
    XCTAssertNil(stored.weatherVersion)
    XCTAssertEqual(stored.healthWindowStatistics[.heartRate]?.mean24h, 60.0)
    XCTAssertNil(stored.healthWindowStatistics[.heartRate]?.range48h)

    row.updateWithWindowStatistics(health: [:], weather: nil, at: baseDate)
    XCTAssertTrue(stored.healthWindowStatistics.isEmpty)
    XCTAssertEqual(stored.healthVersion, Constants.trainingDataContextVersion)
  }

  func testModelInputCodesWindowStatistics() throws {
    var input = makeInput(at: baseDate)
    input.healthWindowStatistics = [.heartRate: WindowStatistics(mean24h: 65.0, delta24h: 5.0)]
    input.weatherWindowStatistics = [.humidity: WindowStatistics(range48h: 0.2)]
    input.previousHealthKitData = [.heartRate: 62.0]

    let data = try JSONEncoder().encode(input)
    let decoded = try JSONDecoder().decode(ModelInput.self, from: data)
    XCTAssertEqual(decoded.healthWindowStatistics, input.healthWindowStatistics)
    XCTAssertEqual(decoded.weatherWindowStatistics, input.weatherWindowStatistics)
    XCTAssertEqual(decoded.previousHealthKitData, input.previousHealthKitData)
    XCTAssertEqual(decoded.date, input.date)
  }

  // MARK: Evaluation outcomes

  func testEvaluationActualOutcomeStoresAndReconstructs() throws {
    let evaluation = Evaluation(context: context)
    evaluation.predictedProbability = 0.7
    evaluation.resolved = false
    XCTAssertNil(evaluation.actualOutcome, "unresolved rows have no outcome")

    // A row resolved before model 2.5 only knows it was wrong: a 0.7
    // forecast that was wrong means no onset followed.
    evaluation.resolved = true
    evaluation.outlook = false
    XCTAssertEqual(evaluation.actualOutcome, false)
    evaluation.outlook = true
    XCTAssertEqual(evaluation.actualOutcome, true)

    // Stored outcomes win over the reconstruction.
    evaluation.actualOutcome = false
    XCTAssertEqual(evaluation.actualOutcomeRaw, 0)
    XCTAssertEqual(evaluation.actualOutcome, false)
    evaluation.actualOutcome = nil
    XCTAssertEqual(evaluation.actualOutcomeRaw, -1)

    XCTAssertNil(Evaluation.reconstructedOutcome(probability: -1.0, wasCorrect: true))
    XCTAssertEqual(Evaluation.reconstructedOutcome(probability: 0.2, wasCorrect: false), true)
  }

  // MARK: Migration

  func testStoreMigrates24To25PreservingData() throws {
    let momdURL = try XCTUnwrap(Bundle.main.url(forResource: "Headache_Tracker", withExtension: "momd"))
    let model24 = try XCTUnwrap(NSManagedObjectModel(contentsOf: momdURL.appendingPathComponent("Headache_Tracker 2.4.mom")))
    let model25 = try XCTUnwrap(NSManagedObjectModel(contentsOf: momdURL.appendingPathComponent("Headache_Tracker 2.5.mom")))

    let storeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("migration-\(UUID().uuidString).sqlite")
    defer {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
      }
    }

    let coordinator24 = NSPersistentStoreCoordinator(managedObjectModel: model24)
    try coordinator24.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
    let context24 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context24.persistentStoreCoordinator = coordinator24

    let row = NSEntityDescription.insertNewObject(forEntityName: "TrainingData", into: context24)
    row.setValue(baseDate, forKey: "timestamp")
    let evaluation = NSEntityDescription.insertNewObject(forEntityName: "Evaluation", into: context24)
    evaluation.setValue(0.42, forKey: "predictedProbability")
    evaluation.setValue(true, forKey: "resolved")
    evaluation.setValue(false, forKey: "outlook")
    try context24.save()
    for store in coordinator24.persistentStores {
      try coordinator24.remove(store)
    }

    let coordinator25 = NSPersistentStoreCoordinator(managedObjectModel: model25)
    try coordinator25.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: [
      NSMigratePersistentStoresAutomaticallyOption: true,
      NSInferMappingModelAutomaticallyOption: true
    ])
    let context25 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context25.persistentStoreCoordinator = coordinator25

    let rows = try context25.fetch(NSFetchRequest<NSManagedObject>(entityName: "TrainingData"))
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.value(forKey: "timestamp") as? Date, baseDate)
    XCTAssertEqual(rows.first?.value(forKey: "source") as? Int16, 0, "migrated rows read as unknown source")
    XCTAssertNil(rows.first?.value(forKey: "contextData"))

    let evaluations = try context25.fetch(NSFetchRequest<NSManagedObject>(entityName: "Evaluation"))
    XCTAssertEqual(evaluations.count, 1)
    XCTAssertEqual(evaluations.first?.value(forKey: "actualOutcomeRaw") as? Int16, -1, "migrated evaluations have no stored outcome")

    XCTAssertNotNil(model25.entitiesByName["ContextData"]?.attributesByName["heartRateRange48h"])
    XCTAssertNil(model24.entitiesByName["ContextData"])
    XCTAssertEqual(model25.configurations.sorted(), ["Cloud", "Local", "PF_DEFAULT_CONFIGURATION_NAME"])
    XCTAssertTrue(model25.entities(forConfigurationName: "Local")?.contains(where: { $0.name == "ContextData" }) ?? false)
    XCTAssertFalse(model25.entities(forConfigurationName: "Cloud")?.contains(where: { $0.name == "ContextData" }) ?? true)
  }

}
