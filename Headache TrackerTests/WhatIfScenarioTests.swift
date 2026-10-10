//
//  WhatIfScenarioTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 10/3/26.
//

import XCTest
@testable import Headache_Tracker

/// Tests for the what-if scenario model: presets, the snap detent,
/// interpolation, the shared y-domain, and input assembly.
final class WhatIfScenarioTests: XCTestCase {

  private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

  private var baseInput: ModelInput {
    return ModelInput(
      date: Calendar.current.startOfDay(for: baseDate).addingTimeInterval(9.0 * 3600.0),
      location: nil,
      weatherStatistics: WeatherStatistics(barometricPressure: nil, currentPressure: 101.3, currentHumidity: 0.5, currentTemperature: 20.0, sigmaPressure: 0.1, sigmaHumidity: 0.0, sigmaTemperature: 0.5),
      healthKitData: [.sleepSeconds: 6.0 * 3600.0, .heartRateVariabilitySDNN: 40.0],
      previousHealthKitData: [.heartRateVariabilitySDNN: 44.0])
  }

  private var sleep: WhatIfDimension { WhatIfDimension(signal: .health(.sleepSeconds), range: 0.0 ... 12.0 * 3600.0, isRemovable: false)! }
  private var pressure: WhatIfDimension { WhatIfDimension(signal: .weather(.currentPressure), range: 98.0 ... 104.0, isRemovable: false)! }
  private var hrv: WhatIfDimension { WhatIfDimension(signal: .health(.heartRateVariabilitySDNN), range: 10.0 ... 100.0, isRemovable: false)! }

  private func baseline(_ mean: Double, _ std: Double, count: Int = 10) -> FeatureBaseline {
    return FeatureBaseline(mean: mean, std: std, count: count)
  }

  // MARK: Presets

  func testPresetsFromBaselines() throws {
    let dimensions = [WhatIfDimension.timeOfDay, sleep, pressure, hrv]
    let scenario = WhatIfScenario(baseInput: baseInput, dimensions: dimensions)
    let baselines: [CorrelationFeature: FeatureBaseline] = [
      .sleepSeconds: baseline(7.0 * 3600.0, 3600.0),
      .heartRateVariability: baseline(45.0, 8.0),
    ]

    let presets = WhatIfScenario.presets(dimensions: dimensions, initialValues: scenario.initialValues, baselines: baselines)
    let byID = Dictionary(uniqueKeysWithValues: presets.map({ ($0.id, $0) }))

    // Slept 6h: a good night is the mean plus one sigma.
    XCTAssertEqual(try XCTUnwrap(byID["goodSleep"]?.values[sleep.id]), 8.0 * 3600.0, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(byID["pressureDrop"]?.values[pressure.id]), 100.3, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(byID["calmHRV"]?.values[hrv.id]), 53.0, accuracy: 1e-9)
    let usual = try XCTUnwrap(byID["usual"])
    XCTAssertEqual(usual.values.count, 2, "pressure has no baseline, so only sleep and HRV")
    XCTAssertEqual(try XCTUnwrap(usual.values[sleep.id]), 7.0 * 3600.0, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(byID["later"]?.values[WhatIfDimension.timeOfDayID]), 15.0, accuracy: 1e-9)

    // Slept 9h already: a good night falls back to the mean.
    var rested = baseInput
    rested.healthKitData?[.sleepSeconds] = 9.0 * 3600.0
    let restedScenario = WhatIfScenario(baseInput: rested, dimensions: dimensions)
    let restedPresets = WhatIfScenario.presets(dimensions: dimensions, initialValues: restedScenario.initialValues, baselines: baselines)
    XCTAssertEqual(try XCTUnwrap(restedPresets.first(where: { $0.id == "goodSleep" })?.values[sleep.id]), 7.0 * 3600.0, accuracy: 1e-9)

    // A thin baseline emits nothing, and a preset that wouldn't move is dropped.
    let thin: [CorrelationFeature: FeatureBaseline] = [.sleepSeconds: baseline(7.0 * 3600.0, 3600.0, count: 3), .heartRateVariability: baseline(40.0, 0.0)]
    let thinPresets = WhatIfScenario.presets(dimensions: dimensions, initialValues: scenario.initialValues, baselines: thin)
    XCTAssertFalse(thinPresets.contains(where: { $0.id == "goodSleep" }))
    XCTAssertFalse(thinPresets.contains(where: { $0.id == "calmHRV" }))
    XCTAssertFalse(thinPresets.contains(where: { $0.id == "usual" }))
    XCTAssertTrue(thinPresets.contains(where: { $0.id == "pressureDrop" }))

    // Late in the day "later" is dropped; a 23:30 start caps instead of wrapping.
    var late = baseInput
    late.date = Calendar.current.startOfDay(for: baseDate).addingTimeInterval(23.5 * 3600.0)
    let lateScenario = WhatIfScenario(baseInput: late, dimensions: [WhatIfDimension.timeOfDay])
    XCTAssertTrue(WhatIfScenario.presets(dimensions: [WhatIfDimension.timeOfDay], initialValues: lateScenario.initialValues, baselines: [:]).isEmpty)
  }

  func testPresetApplyAndIsActiveToggle() throws {
    let dimensions = [WhatIfDimension.timeOfDay, sleep, hrv]
    var scenario = WhatIfScenario(baseInput: baseInput, dimensions: dimensions)
    let preset = WhatIfPreset(id: "goodSleep", title: "", systemImage: "", values: [sleep.id: 8.0 * 3600.0])

    XCTAssertFalse(scenario.isActive(preset))
    scenario.apply(preset)
    XCTAssertTrue(scenario.isActive(preset))
    XCTAssertTrue(scenario.isModified)
    XCTAssertEqual(scenario.values[hrv.id], scenario.initialValues[hrv.id], "other sliders return to their starting values")

    scenario.values[hrv.id] = 60.0
    XCTAssertFalse(scenario.isActive(preset), "another slider moving leaves the preset")

    scenario.reset()
    XCTAssertFalse(scenario.isModified)

    // Out-of-range preset values clamp to the slider.
    scenario.apply(WhatIfPreset(id: "x", title: "", systemImage: "", values: [sleep.id: 99.0 * 3600.0]))
    XCTAssertEqual(scenario.values[sleep.id], 12.0 * 3600.0)
  }

  // MARK: Math

  func testSnapDetent() {
    let range = 0.0 ... 100.0
    XCTAssertEqual(WhatIfScenario.snapped(51.9, toward: 50.0, range: range), 50.0)
    XCTAssertEqual(WhatIfScenario.snapped(52.1, toward: 50.0, range: range), 52.1)
    XCTAssertEqual(WhatIfScenario.snapped(48.1, toward: 50.0, range: range), 50.0)
    XCTAssertEqual(WhatIfScenario.snapped(48.0, toward: 50.0, range: range), 50.0, "boundary is inclusive")
    XCTAssertEqual(WhatIfScenario.snapped(7.0, toward: 7.0, range: 7.0 ... 7.0), 7.0, "a zero-span range passes values through")
    XCTAssertEqual(WhatIfScenario.snapped(3.0, toward: 7.0, range: 7.0 ... 7.0), 3.0)
  }

  func testInterpolation() throws {
    let curve = [CurvePoint(id: 0, value: 0.0, probability: 0.1), CurvePoint(id: 1, value: 10.0, probability: 0.3)]
    XCTAssertEqual(try XCTUnwrap(WhatIfScenario.interpolatedProbability(curve: curve, at: 5.0)), 0.2, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(WhatIfScenario.interpolatedProbability(curve: curve, at: -1.0)), 0.1, accuracy: 1e-9)
    XCTAssertEqual(try XCTUnwrap(WhatIfScenario.interpolatedProbability(curve: curve, at: 11.0)), 0.3, accuracy: 1e-9)
    XCTAssertNil(WhatIfScenario.interpolatedProbability(curve: [], at: 1.0))
    // Unsorted input is sorted first.
    XCTAssertEqual(try XCTUnwrap(WhatIfScenario.interpolatedProbability(curve: curve.reversed(), at: 2.5)), 0.15, accuracy: 1e-9)
  }

  func testSharedYDomainAndSwing() {
    let low = [CurvePoint(id: 0, value: 0, probability: 0.1), CurvePoint(id: 1, value: 1, probability: 0.2)]
    let mid = [CurvePoint(id: 0, value: 0, probability: 0.2), CurvePoint(id: 1, value: 1, probability: 0.7)]
    let high = [CurvePoint(id: 0, value: 0, probability: 0.5), CurvePoint(id: 1, value: 1, probability: 0.98)]
    XCTAssertEqual(WhatIfScenario.sharedYDomain(curves: [low]).upperBound, 0.35, accuracy: 1e-9)
    XCTAssertEqual(WhatIfScenario.sharedYDomain(curves: [low, mid]).upperBound, 0.75, accuracy: 1e-9)
    XCTAssertEqual(WhatIfScenario.sharedYDomain(curves: [high]).upperBound, 1.0, accuracy: 1e-9)
    XCTAssertEqual(WhatIfScenario.sharedYDomain(curves: []).lowerBound, 0.0)
    XCTAssertEqual(WhatIfScenario.swing(of: mid) ?? 0.0, 0.5, accuracy: 1e-9)
    XCTAssertNil(WhatIfScenario.swing(of: [low[0]]))
  }

  // MARK: Inputs

  func testInputLeavesUntouchedDimensionsAlone() {
    let dimensions = [WhatIfDimension.timeOfDay, sleep, hrv]
    var scenario = WhatIfScenario(baseInput: baseInput, dimensions: dimensions)

    // Resting: exactly the base.
    let resting = scenario.input()
    XCTAssertEqual(resting.date, baseInput.date)
    XCTAssertEqual(resting.healthKitData, baseInput.healthKitData)
    XCTAssertEqual(resting.weatherStatistics?.currentPressure, 101.3)

    // Move sleep only: HRV and the clock stay put.
    scenario.values[sleep.id] = 8.0 * 3600.0
    let moved = scenario.input()
    XCTAssertEqual(moved.healthKitData?[.sleepSeconds], 8.0 * 3600.0)
    XCTAssertEqual(moved.healthKitData?[.heartRateVariabilitySDNN], 40.0)
    XCTAssertEqual(moved.date, baseInput.date)
    XCTAssertEqual(moved.previousHealthKitData, baseInput.previousHealthKitData)

    // Time of day moves the clock on the same day.
    scenario.values[WhatIfDimension.timeOfDayID] = 15.0
    let later = scenario.input()
    XCTAssertEqual(Calendar.current.component(.hour, from: later.date), 15)
    XCTAssertEqual(Calendar.current.startOfDay(for: later.date), Calendar.current.startOfDay(for: baseInput.date))

    // Sweeps hold the other sliders where they are.
    let sweeps = scenario.sweepInputs(count: 5)
    XCTAssertEqual(sweeps.count, 3)
    let hrvSweep = sweeps.first(where: { $0.id == hrv.id })!
    XCTAssertEqual(hrvSweep.inputs.count, 5)
    XCTAssertEqual(hrvSweep.inputs[0].healthKitData?[.sleepSeconds], 8.0 * 3600.0)
    XCTAssertEqual(hrvSweep.inputs[0].healthKitData?[.heartRateVariabilitySDNN], 10.0)
  }

  func testAddAndRemoveSeedInitialValues() {
    var scenario = WhatIfScenario(baseInput: baseInput, dimensions: [WhatIfDimension.timeOfDay, sleep])
    XCTAssertFalse(scenario.isModified)

    scenario.add(pressure)
    XCTAssertEqual(scenario.dimensions.count, 3)
    XCTAssertEqual(scenario.initialValues[pressure.id], 101.3)
    XCTAssertFalse(scenario.isModified, "an added signal starts at its reading")

    scenario.add(pressure)
    XCTAssertEqual(scenario.dimensions.count, 3, "no duplicates")

    scenario.remove(id: pressure.id)
    XCTAssertEqual(scenario.dimensions.count, 2)
    XCTAssertNil(scenario.values[pressure.id])
    XCTAssertNil(scenario.initialValues[pressure.id])

    // A signal the base never carried starts mid-range.
    let humidity = WhatIfDimension(signal: .weather(.humidity), range: 0.0 ... 1.0, isRemovable: true)!
    var bare = baseInput
    bare.weatherStatistics = nil
    var bareScenario = WhatIfScenario(baseInput: bare, dimensions: [humidity])
    XCTAssertEqual(bareScenario.initialValues[humidity.id], 0.5)
    XCTAssertNil(bareScenario.input().weatherStatistics, "untouched, it isn't injected")
    bareScenario.values[humidity.id] = 0.8
    XCTAssertNil(bareScenario.input().weatherStatistics, "settingValue can't invent weather from nothing")
  }

  func testSleepOnsetIsNotAdjustable() {
    let candidates: [RiskSignal] = [.health(.sleepOnset), .health(.sleepSeconds)]
    XCTAssertEqual(WhatIfScenario.adjustable(candidates), [.health(.sleepSeconds)])
    XCTAssertEqual(WhatIfScenario.rankSignals(candidates: candidates, contributions: [], importances: [:], limit: 4).count, 1)
    XCTAssertNil(WhatIfDimension(signal: .health(.sleepSeconds), range: 5.0 ... 5.0, isRemovable: false), "an empty range makes no dimension")
  }

  func testTimeOfDayFormatting() {
    let dimension = WhatIfDimension.timeOfDay
    XCTAssertEqual(dimension.format(0.0, referenceDate: baseDate), Formatters.formatTime(Calendar.current.startOfDay(for: baseDate)))
    XCTAssertLessThan(dimension.range.upperBound, 24.0, "24 would wrap to midnight")
  }

  func testStubScoresCarryTwoHorizons() async throws {
    let predictor = Predictor()
    let scores = try await predictor.scores(for: [baseInput, baseInput.settingValue(3.0 * 3600.0, for: .health(.sleepSeconds))])
    XCTAssertEqual(scores.count, 2)
    for score in scores {
      XCTAssertTrue(score.hasModel)
      XCTAssertLessThan(try XCTUnwrap(score.probability12), score.probability24)
    }
    XCTAssertGreaterThan(scores[1].probability24, scores[0].probability24)
    XCTAssertGreaterThan(try XCTUnwrap(scores[1].probability12), try XCTUnwrap(scores[0].probability12))
  }

}
