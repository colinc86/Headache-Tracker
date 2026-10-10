//
//  ProfileAndSummaryTests.swift
//  Headache TrackerTests
//
//  Created by Colin Campbell on 10/4/26.
//

import XCTest
@testable import Headache_Tracker

/// The pure logic behind the Track and Profile redesign: profile analytics,
/// the streak strip, forecast drivers, the summary fact sheets, the template
/// writer, the language-model validator, and the summary cache.
final class ProfileAndSummaryTests: XCTestCase {

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    return calendar
  }

  /// Noon on Wednesday, Oct 1 2026.
  private var now: Date {
    return calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
  }

  /// An episode starting `daysAgo` days before `now` at `hour`, mild then
  /// `peak` after 30 minutes, ending after `hours`.
  private func episode(daysAgo: Int, hour: Int, peak: Headache.Severity = .moderate, hours: Double = 3.0, ongoing: Bool = false) -> HeadacheEpisode {
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
    let start = calendar.date(byAdding: .hour, value: hour, to: day)!
    let end = ongoing ? nil : start.addingTimeInterval(hours * 3600.0)
    return HeadacheEpisode(start: start, end: end, severities: [
      .init(severity: .mild, start: start, end: start.addingTimeInterval(1800.0)),
      .init(severity: peak, start: start.addingTimeInterval(1800.0), end: end)
    ])
  }

  // MARK: Profile analytics

  func testRhythmTypicalWindowAndPeakWeekday() {
    // Three evening headaches on the same weekday, one morning one.
    let episodes = [episode(daysAgo: 7, hour: 21), episode(daysAgo: 14, hour: 22), episode(daysAgo: 21, hour: 21), episode(daysAgo: 3, hour: 9)]
    let analytics = ProfileAnalytics.make(episodes: episodes, now: now, calendar: calendar)

    XCTAssertEqual(analytics.headacheCount, 4)
    XCTAssertEqual(analytics.rhythm.flatMap({ $0 }).reduce(0, +), 4)
    let weekday = calendar.component(.weekday, from: episodes[0].start) - 1
    XCTAssertEqual(analytics.rhythm[weekday][21], 2)
    XCTAssertEqual(analytics.peakWeekday, weekday)
    XCTAssertEqual(analytics.typicalOnsetHour.map({ (21 - $0 + 24) % 24 <= 2 }), true, "the busiest window covers 9–10 PM")
    XCTAssertEqual(analytics.medianDuration ?? 0, 3.0 * 3600.0, accuracy: 1.0)
    XCTAssertEqual(analytics.commonPeak, .moderate)
  }

  func testRateDirectionAndWindowing() {
    // Five recent headaches, one old one, one outside the window.
    var episodes = (1 ... 5).map({ episode(daysAgo: $0 * 4, hour: 8) })
    episodes.append(episode(daysAgo: 80, hour: 8))
    episodes.append(episode(daysAgo: 200, hour: 8))
    let analytics = ProfileAnalytics.make(episodes: episodes, now: now, calendar: calendar, windowDays: 90)

    XCTAssertEqual(analytics.headacheCount, 6)
    XCTAssertEqual(analytics.ratePerMonth, 6.0 / (90.0 / 30.44), accuracy: 1e-9)
    XCTAssertEqual(analytics.direction, .rising)
  }

  func testLongestFreeStreakAndMedianCurve() {
    let episodes = [episode(daysAgo: 30, hour: 10), episode(daysAgo: 10, hour: 10)]
    let analytics = ProfileAnalytics.make(episodes: episodes, now: now, calendar: calendar, windowDays: 40)
    XCTAssertEqual(analytics.longestFreeStreak, 19, "the 19 days between the two headaches")

    // Both curves: mild for 30 min, moderate to 3 h, then nothing.
    XCTAssertFalse(analytics.medianCurve.isEmpty)
    let at15 = analytics.medianCurve.first(where: { abs($0.hours - 0.25) < 1e-9 })
    let at2 = analytics.medianCurve.first(where: { abs($0.hours - 2.0) < 1e-9 })
    XCTAssertEqual(at15?.severity, Double(Headache.Severity.mild.orderingValue))
    XCTAssertEqual(at2?.severity, Double(Headache.Severity.moderate.orderingValue))
    XCTAssertEqual(analytics.curveHours, 3.0, accuracy: 1e-9)
    XCTAssertEqual(Set(analytics.curves.map({ $0.series })), [0, 1])
  }

  func testHourText() {
    XCTAssertEqual(ProfileAnalytics.hourText(0), "12 AM")
    XCTAssertEqual(ProfileAnalytics.hourText(9), "9 AM")
    XCTAssertEqual(ProfileAnalytics.hourText(12), "12 PM")
    XCTAssertEqual(ProfileAnalytics.hourText(21), "9 PM")
  }

  func testEmptyProfile() {
    let analytics = ProfileAnalytics.make(episodes: [], now: now, calendar: calendar)
    XCTAssertEqual(analytics.headacheCount, 0)
    XCTAssertNil(analytics.typicalOnsetHour)
    XCTAssertTrue(analytics.medianCurve.isEmpty)
    XCTAssertEqual(analytics.direction, .steady)
  }

  // MARK: Streak

  func testStreakStripAndRuns() {
    let episodes = [episode(daysAgo: 20, hour: 10, peak: .severe), episode(daysAgo: 4, hour: 10, peak: .mild)]
    let streak = StreakSummary.make(episodes: episodes, now: now, calendar: calendar)

    XCTAssertEqual(streak.days.count, 14)
    XCTAssertTrue(streak.days.last?.isToday == true)
    XCTAssertEqual(streak.days.filter({ $0.peak != nil }).count, 1)
    XCTAssertEqual(streak.days[13 - 4].peak, .mild, "the episode's worst severity colors its day")
    XCTAssertEqual(streak.currentFreeDays, 3)
    XCTAssertEqual(streak.longestFreeStreak, 15)
  }

  func testStreakDuringAHeadacheAndBeforeAny() {
    let ongoing = StreakSummary.make(episodes: [episode(daysAgo: 0, hour: 9, ongoing: true)], now: now, calendar: calendar)
    XCTAssertEqual(ongoing.currentFreeDays, 0)
    let none = StreakSummary.make(episodes: [], now: now, calendar: calendar)
    XCTAssertNil(none.currentFreeDays)
    XCTAssertEqual(none.longestFreeStreak, 0)
  }

  // MARK: Drivers and facts

  private func report() -> InsightsReport {
    return InsightsReport(
      generatedAt: now,
      rowCount: 100,
      insights: [
        TriggerInsight(feature: .sleepSeconds, target: .occurrence, coefficient: -0.58, qValue: 0.004, bestLagHours: 24, lagProfile: [24: -0.58], sampleCount: 96, eventCount: 22, positiveMean: 5.2 * 3600.0, baselineMean: 7.1 * 3600.0, usesBaselineRelative: true, explainedBy: nil, partialCoefficient: nil),
        TriggerInsight(feature: .sigmaPressure, target: .occurrence, coefficient: 0.41, qValue: 0.03, bestLagHours: 12, lagProfile: [12: 0.41], sampleCount: 88, eventCount: 19, positiveMean: 0.9, baselineMean: 0.3, usesBaselineRelative: true, explainedBy: nil, partialCoefficient: nil)
      ],
      insufficient: [],
      baselines: [
        .sleepSeconds: FeatureBaseline(mean: 7.1 * 3600.0, std: 3600.0, count: 30),
        .sigmaPressure: FeatureBaseline(mean: 0.3, std: 0.2, count: 30)
      ],
      schemaVersion: InsightsReport.currentSchemaVersion,
      enabledFingerprint: "")
  }

  func testDriversMergeContributionsThenDeviations() {
    var prediction = Previewing.Prediction.prediction
    prediction.contributions = [
      RiskPrediction.RiskContribution(feature: .restingHeartRate, mlFeatureName: "Resting Heart Rate", delta: -0.03),
      RiskPrediction.RiskContribution(feature: .sleepSeconds, mlFeatureName: "Sleep Seconds", delta: 0.11)
    ]
    let drivers = RiskDriver.make(prediction: prediction, report: report())

    XCTAssertEqual(drivers.map({ $0.feature }), [.sleepSeconds, .restingHeartRate, .sigmaPressure])
    XCTAssertEqual(drivers[0].deltaText, "+11")
    XCTAssertEqual(drivers[1].deltaText, "−3")
    XCTAssertFalse(drivers[1].raising)
    XCTAssertNil(drivers[2].delta, "a deviation behind an insight with no model attribution")
    XCTAssertEqual(drivers[0].usualText, CorrelationFeature.sleepSeconds.format(7.1 * 3600.0))
  }

  func testRiskFactsAndTemplate() throws {
    let prediction = Previewing.Prediction.prediction
    let drivers = RiskDriver.make(prediction: prediction, report: report())
    let facts = try XCTUnwrap(RiskFacts.make(prediction: prediction, drivers: drivers, history: []))
    XCTAssertEqual(facts.percent, 42)
    XCTAssertEqual(facts.tier, "elevated")
    XCTAssertEqual(facts.likelyRange, "33–52%")
    XCTAssertLessThanOrEqual(facts.drivers.count, 3)

    let summary = TemplateSummaryWriter().riskSummary(facts)
    XCTAssertFalse(summary.isGenerated)
    XCTAssertTrue(summary.text.hasPrefix("Sleep duration at"), summary.text)
    XCTAssertTrue(summary.text.contains("pushing your risk up"))
    XCTAssertTrue(SummaryValidator.isValid(summary.text, grounding: facts.groundingStrings, signalNames: facts.signalNames, maxSentences: 2, maxCharacters: 220), "the template passes the model's own validator")
    XCTAssertNil(RiskFacts.make(prediction: .empty, drivers: [], history: []))
  }

  func testQuietTemplateAndTiming() {
    let facts = RiskFacts(percent: 12, tier: "low", likelyRange: nil, trend: "rising", timing: "Mostly in the next 12 hours", drivers: [], estimatedSignals: 0)
    XCTAssertEqual(TemplateSummaryWriter().riskSummary(facts).text, "Nothing in your signals stands out today. Mostly in the next 12 hours, and climbing.")
  }

  func testProfileFactsAndPortrait() {
    let episodes = [episode(daysAgo: 7, hour: 21), episode(daysAgo: 14, hour: 22), episode(daysAgo: 21, hour: 21)]
    let analytics = ProfileAnalytics.make(episodes: episodes, now: now, calendar: calendar)
    let medications = [ClinicianReportData.MedicationSummary(name: "Sumatriptan", count: 4, helpfulCount: 3, ratedCount: 4)]
    let facts = ProfileFacts.make(analytics: analytics, report: report(), medications: medications, accuracy: ForecastAccuracy(value: 0.71, source: .outOfFold, count: 0))

    XCTAssertEqual(facts.headaches, 3)
    XCTAssertEqual(facts.patterns.map({ $0.id }), ["sleepSeconds", "sigmaPressure"])
    XCTAssertEqual(facts.leadingAreas.first, "Sleep")
    XCTAssertEqual(facts.mostHelpfulMedication, "Sumatriptan, helped 3 of 4 times")
    XCTAssertEqual(facts.forecastAccuracy, "71% accurate")

    let portrait = TemplateSummaryWriter().portrait(facts)
    XCTAssertTrue(portrait.headline.hasPrefix("Sleep and"), portrait.headline)
    XCTAssertTrue(portrait.body.hasPrefix("3 headaches in the last 90 days"), portrait.body)
    XCTAssertLessThanOrEqual(SummaryValidator.sentenceCount(portrait.body), 3)
    XCTAssertEqual(portrait.insightLines["sigmaPressure"], "Higher pressure change before headaches, most clearly about 12 hours ahead.")
    XCTAssertTrue(SummaryValidator.isValid(portrait.body, grounding: facts.groundingStrings, signalNames: facts.signalNames, maxSentences: 3, maxCharacters: 420), portrait.body)
  }

  // MARK: Validator

  func testValidatorRejectsUngroundedNumbersSignalsAdviceAndLength() {
    let grounding = ["5h 12m", "7h 6m", "11", "33–52%"]
    let names = ["Sleep Duration"]
    XCTAssertTrue(SummaryValidator.isValid("Short sleep (5h 12m against your usual 7h 6m) is lifting your risk.", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220))
    XCTAssertFalse(SummaryValidator.isValid("Your risk is 80% today.", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220), "an invented number")
    XCTAssertFalse(SummaryValidator.isValid("Higher resting heart rate is part of it.", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220), "a signal the facts don't mention")
    XCTAssertFalse(SummaryValidator.isValid("You should take your medication early.", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220), "advice")
    XCTAssertFalse(SummaryValidator.isValid("One. Two. Three.", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220), "too many sentences")
    XCTAssertFalse(SummaryValidator.isValid("   ", grounding: grounding, signalNames: names, maxSentences: 2, maxCharacters: 220))
    XCTAssertTrue(SummaryValidator.isValid("It peaks within 12 hours.", grounding: [], signalNames: [], maxSentences: 2, maxCharacters: 220), "the horizons are always allowed")
  }

  func testNumberExtraction() {
    XCTAssertEqual(SummaryValidator.numbers(in: "5h 12m vs 7.1, and 33–52%"), ["5", "12", "7.1", "33", "52"])
  }

  // MARK: Cache

  func testCacheKeysFollowTheFacts() {
    let a = RiskFacts(percent: 42, tier: "elevated", likelyRange: nil, trend: nil, timing: nil, drivers: [], estimatedSignals: 0)
    let b = RiskFacts(percent: 42, tier: "elevated", likelyRange: nil, trend: nil, timing: nil, drivers: [], estimatedSignals: 0)
    let c = RiskFacts(percent: 43, tier: "elevated", likelyRange: nil, trend: nil, timing: nil, drivers: [], estimatedSignals: 0)
    XCTAssertEqual(a.summaryCacheKey, b.summaryCacheKey)
    XCTAssertNotEqual(a.summaryCacheKey, c.summaryCacheKey)
    XCTAssertEqual(a.summaryCacheKey.count, 64)
  }

  func testStoreKeepsGeneratedSummariesByKey() {
    let store = SummaryStore.shared
    store.removeAll()
    defer { store.removeAll() }

    let text = SummaryText(text: "Short sleep is lifting your risk.", isGenerated: true)
    store.save(risk: text, for: "k1")
    XCTAssertEqual(store.risk(for: "k1"), text)
    XCTAssertNil(store.risk(for: "k2"))

    for index in 0 ..< SummaryStore.riskCapacity + 2 {
      store.save(risk: text, for: "extra\(index)")
    }
    XCTAssertNil(store.risk(for: "k1"), "the oldest entries are evicted")

    let portrait = ProfilePortrait(headline: "Sleep leads your headaches", body: "Body.", insightLines: [:], isGenerated: true)
    store.save(portrait: portrait, for: "p1", now: now)
    XCTAssertEqual(store.portrait(for: "p1", now: now.addingTimeInterval(3600.0)), portrait)
    XCTAssertNil(store.portrait(for: "p1", now: now.addingTimeInterval(SummaryStore.portraitLifetime + 1.0)))
    XCTAssertNil(store.portrait(for: "p2", now: now))
  }

}
