//
//  ModelInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import CoreLocation
import Foundation

/// A prediction horizon: the window ahead within which an onset counts as a
/// positive. The standard 24-hour horizon is the long-standing forecast; the
/// short horizon targets the tighter window where autonomic prodrome
/// precursors are strongest.
enum RiskHorizon {
  case standard
  case short

  /// The window ahead of a sample within which an onset is a positive.
  var window: TimeInterval {
    switch self {
    case .standard: return 86400.0
    case .short: return 12.0 * 3600.0
    }
  }
}

/// A prediction input.
struct ModelInput: Codable {
  
  enum CodingKeys: CodingKey {
    case date
    case weatherStatistics
    case healthKitData
    // Persisted: without it, a prediction decoded from the shared defaults
    // loses every baseline *slope* (they need a prior reading to form), so
    // the ten `… Baseline Slope` columns silently pin to 0 — which both
    // drifts the score from the live one and makes the what-if explorer far
    // less responsive than the real hourly forecast.
    case previousHealthKitData
    // Persisted for the same reason: the temporal-context columns must
    // survive a decoded forecast so the what-if explorer and the input
    // inspector re-score exactly what the hourly refresh scored.
    case healthWindowStatistics
    case weatherWindowStatistics
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

  /// The health kit reading from ~`BaselineFeatures.slopeGap` earlier, used to
  /// form baseline-relative slopes at inference. Derived, but persisted — see
  /// `CodingKeys`.
  var previousHealthKitData: [HealthKitData: Double]?

  /// Trailing fixed-clock-window statistics per HealthKit metric (24h mean
  /// and delta, 48h/72h range, 6h delta), read from hourly HealthKit buckets
  /// at inference and stored with each training row. Absent metrics are
  /// median-imputed like every other column.
  var healthWindowStatistics: [HealthKitData: WindowStatistics]?

  /// Trailing window statistics per station weather field, from WeatherKit's
  /// hourly history.
  var weatherWindowStatistics: [WeatherField: WindowStatistics]?

  /// The time interval until the next headache begins.
  var timeIntervalUntilNextHeadacheStart: TimeInterval?
  
  /// The time interval until the current headache ends.
  var timeIntervalUntilNextHeadacheEnd: TimeInterval?
  
  /// The input's outlook.
  var outlook: Outlook
  
  /// The input's severity.
  var severity: Headache.Severity

  /// Per-metric personal-baseline z-scores (deviation from the user's own
  /// rolling 14-day baseline). Derived, not persisted; absent metrics fall
  /// back to the baseline provider's neutral default.
  var baselineZ: [HealthKitData: Double]?

  /// Per-metric short-window slopes (rate of change vs. baseline). Derived,
  /// not persisted. Populated in a later step.
  var baselineSlope: [HealthKitData: Double]?

  /// The features whose extended temporal-context columns the model carries
  /// (see `TemporalContextInput`). Set by the predictor from its persisted
  /// personalization sidecar at inference and by training per variant.
  /// Derived, not persisted.
  var personalizedFeatures: Set<CorrelationFeature>?

  // MARK: Initializers

  /// Initializes new model input.
  init(date: Date, location: CLLocation?, weatherStatistics: WeatherStatistics?, healthKitData: [HealthKitData: Double]?, previousHealthKitData: [HealthKitData: Double]? = nil, healthWindowStatistics: [HealthKitData: WindowStatistics]? = nil, weatherWindowStatistics: [WeatherField: WindowStatistics]? = nil, timeIntervalUntilNextHeadacheStart: TimeInterval? = 0.0, timeIntervalUntilNextHeadacheEnd: TimeInterval? = 0.0, outlook: Outlook = .noHeadache, severity: Headache.Severity = .notPresent, baselineZ: [HealthKitData: Double]? = nil, baselineSlope: [HealthKitData: Double]? = nil) {
    self.date = date
    self.location = location
    self.weatherStatistics = weatherStatistics
    self.healthKitData = healthKitData
    self.previousHealthKitData = previousHealthKitData
    self.healthWindowStatistics = healthWindowStatistics
    self.weatherWindowStatistics = weatherWindowStatistics
    self.timeIntervalUntilNextHeadacheStart = timeIntervalUntilNextHeadacheStart
    self.timeIntervalUntilNextHeadacheEnd = timeIntervalUntilNextHeadacheEnd
    self.outlook = outlook
    self.severity = severity
    self.baselineZ = baselineZ
    self.baselineSlope = baselineSlope
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
      healthWindowStatistics: trainingData.contextData?.healthWindowStatistics,
      weatherWindowStatistics: trainingData.contextData?.weatherWindowStatistics,
      timeIntervalUntilNextHeadacheStart: trainingData.timeIntervalUntilNextHeadacheStart,
      timeIntervalUntilNextHeadacheEnd: trainingData.timeIntervalUntilNextHeadacheEnd,
      outlook: trainingData.outlook ?? .noHeadache,
      severity: trainingData.derivedSeverity ?? .notPresent)
  }
  
  /// Whether this input is a positive for the given horizon: an onset occurs
  /// within `horizon.window`. The standard horizon preserves the existing
  /// 24-hour `possibleHeadache` label exactly; the short horizon derives from
  /// the already-computed time-to-next-onset.
  ///
  /// - Parameter horizon: The prediction horizon.
  /// - Returns: Whether the row is a positive.
  func isPositive(horizon: RiskHorizon) -> Bool {
    switch horizon {
    case .standard:
      return outlook == .possibleHeadache
    case .short:
      guard outlook != .headache, let interval = timeIntervalUntilNextHeadacheStart else {
        return false
      }
      return interval >= 0.0 && interval <= horizon.window
    }
  }

  /// The event this row's label comes from, for cluster resampling: rows
  /// before the same upcoming onset share that onset's date; rows with no
  /// upcoming onset cluster by their own calendar day, so the tail of the
  /// series doesn't move as one block.
  ///
  /// - Parameter calendar: The calendar for the day fallback.
  /// - Returns: The cluster identifier.
  func labelCluster(calendar: Calendar = .current) -> Date {
    if let interval = timeIntervalUntilNextHeadacheStart {
      return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate + interval).rounded(.down))
    }
    return calendar.startOfDay(for: date)
  }

  /// The full model input.
  func fullInput() -> InputUnion {
    return InputUnion(providers: [controlledUserInput(), environmentalInput(), chronologicalInput(), uncontrolledUserInput(), autonomicBaselineInput(), temporalContextInput()])
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

  private func autonomicBaselineInput() -> AutonomicBaselineInput {
    return AutonomicBaselineInput(baselineZ: baselineZ, baselineSlope: baselineSlope)
  }

  private func temporalContextInput() -> TemporalContextInput {
    return TemporalContextInput(health: healthWindowStatistics, weather: weatherWindowStatistics, personalized: personalizedFeatures)
  }

}

// MARK: - Attribution

/// A weather field that feeds the model, for per-prediction attribution.
enum WeatherField: String, CaseIterable, Codable {
  case currentPressure
  case devicePressure
  case humidity
  case temperature
  case sigmaPressure
  case sigmaHumidity
  case sigmaTemperature

  /// The correlation feature this field maps to.
  var correlationFeature: CorrelationFeature {
    switch self {
    case .currentPressure: return .pressure
    case .devicePressure: return .devicePressure
    case .humidity: return .humidity
    case .temperature: return .temperature
    case .sigmaPressure: return .sigmaPressure
    case .sigmaHumidity: return .sigmaHumidity
    case .sigmaTemperature: return .sigmaTemperature
    }
  }

  /// This field's current value in a weather reading — the inverse of the
  /// assignment `ModelInput.settingValue(_:for:)` performs.
  ///
  /// - Parameter statistics: The weather reading.
  /// - Returns: The field's value, or nil when the reading doesn't carry it
  ///   (device pressure is absent without a barometer reading).
  func value(from statistics: WeatherStatistics) -> Double? {
    switch self {
    case .currentPressure: return statistics.currentPressure
    case .devicePressure: return statistics.barometricPressure
    case .humidity: return statistics.currentHumidity
    case .temperature: return statistics.currentTemperature
    case .sigmaPressure: return statistics.sigmaPressure
    case .sigmaHumidity: return statistics.sigmaHumidity
    case .sigmaTemperature: return statistics.sigmaTemperature
    }
  }

  /// This field's median, for neutralization.
  func median(from medians: FeatureMedians) -> Double? {
    switch self {
    case .currentPressure: return medians.pressure
    case .devicePressure: return medians.devicePressure
    case .humidity: return medians.humidity
    case .temperature: return medians.temperature
    case .sigmaPressure: return medians.sigmaPressure
    case .sigmaHumidity: return medians.sigmaHumidity
    case .sigmaTemperature: return medians.sigmaTemperature
    }
  }
}

/// A single signal that feeds the risk model, for attribution.
enum RiskSignal: Equatable {
  case health(HealthKitData)
  case weather(WeatherField)

  /// The correlation feature this signal presents as (name, icon, domain).
  var correlationFeature: CorrelationFeature? {
    switch self {
    case .health(let metric): return CorrelationFeature(healthKitData: metric)
    case .weather(let field): return field.correlationFeature
    }
  }

  /// The physically plausible range for this signal, in the units it is
  /// stored in. Used to clamp the data-derived simulation range so a tiny
  /// personal standard deviation can't produce an absurd slider (and a huge
  /// one can't run past what the body or the atmosphere actually does).
  ///
  /// Nil for signals with no sensible simulated range.
  var plausibleBounds: ClosedRange<Double>? {
    switch self {
    case .health(let metric):
      switch metric {
      case .sleepSeconds: return 0.0 ... (14.0 * 3600.0)
      case .sleepOnset: return 0.0 ... (24.0 * 3600.0)
      case .heartRateVariabilitySDNN: return 5.0 ... 200.0
      case .hrvRMSSD: return 5.0 ... 200.0
      case .hrvPNN50: return 0.0 ... 1.0
      case .hrvLFHF: return 0.0 ... 10.0
      case .heartRate, .restingHeartRate, .walkingHeartRateAverage: return 35.0 ... 180.0
      case .respiratoryRate: return 6.0 ... 30.0
      case .oxygenSaturation: return 0.85 ... 1.0
      case .bodyTemperature, .basalBodyTemperature: return 34.0 ... 40.0
      case .wristTemperature: return 30.0 ... 39.0
      case .stepCount: return 0.0 ... 30000.0
      case .mindfulSession: return 0.0 ... (2.0 * 3600.0)
      case .environmentalAudioExposure, .headphoneAudioExposure: return 30.0 ... 110.0
      default: return nil
      }

    case .weather(let field):
      switch field {
      case .currentPressure, .devicePressure: return 95.0 ... 106.0
      case .humidity: return 0.0 ... 1.0
      case .temperature: return -30.0 ... 50.0
      case .sigmaPressure: return 0.0 ... 3.0
      case .sigmaHumidity: return 0.0 ... 0.3
      case .sigmaTemperature: return 0.0 ... 15.0
      }
    }
  }
}

extension ModelInput {

  /// The HealthKit metrics that feed a model feature column (i.e. can be
  /// attributed). Excludes the correlation-only metrics that have no provider
  /// column and the write-only headache type.
  private static let attributableHealthMetrics: Set<HealthKitData> = {
    let excluded: Set<HealthKitData> = [.dietaryCaffeine, .dietaryWater, .timeInDaylight, .appleExerciseTime, .headache]
    return Set(HealthKitData.allCases.filter { !excluded.contains($0) })
  }()

  /// The present signals worth attributing for this input: HealthKit metrics
  /// actually read (and modeled), plus the weather fields when weather exists.
  func attributionCandidates() -> [RiskSignal] {
    var candidates = [RiskSignal]()
    if let healthKitData = healthKitData {
      for metric in healthKitData.keys where ModelInput.attributableHealthMetrics.contains(metric) {
        candidates.append(.health(metric))
      }
    }
    if weatherStatistics != nil {
      candidates.append(contentsOf: WeatherField.allCases.map(RiskSignal.weather))
    }
    return candidates
  }

  /// A copy of this input with one signal set to the user's "normal": the raw
  /// value swapped for its median and, for baseline metrics, its z-score and
  /// slope dropped (→ 0 = "at baseline"). Re-running the model on this and
  /// diffing the probability gives the signal's contribution to the forecast.
  ///
  /// - Parameters:
  ///   - signal: The signal to neutralize.
  ///   - medians: The training-time medians.
  /// - Returns: The neutralized copy.
  func neutralizing(_ signal: RiskSignal, medians: FeatureMedians) -> ModelInput {
    var copy: ModelInput
    switch signal {
    case .health(let metric):
      guard let median = medians.healthKit[metric] else {
        return self
      }
      copy = settingValue(median, for: signal)
      // The signal's window context travels with it: "normal" means the
      // typical swing and drift too, not the live ones.
      if copy.healthWindowStatistics?[metric] != nil {
        copy.healthWindowStatistics?[metric] = medians.healthWindow[metric] ?? WindowStatistics()
      }
    case .weather(let field):
      guard let median = field.median(from: medians) else {
        return self
      }
      copy = settingValue(median, for: .weather(field))
      if copy.weatherWindowStatistics?[field] != nil {
        copy.weatherWindowStatistics?[field] = medians.weatherWindow[field] ?? WindowStatistics()
      }
    }
    return copy
  }

  /// A copy with one signal overridden to an arbitrary value (for the "what
  /// if…" explorer). Baseline z/slope for the changed metric are dropped so
  /// the scorer recomputes them from the new raw value.
  ///
  /// - Parameters:
  ///   - value: The override value (raw units).
  ///   - signal: The signal to override.
  /// - Returns: The modified copy.
  func settingValue(_ value: Double, for signal: RiskSignal) -> ModelInput {
    var copy = self

    switch signal {
    case .health(let metric):
      var data = copy.healthKitData ?? [:]
      data[metric] = value
      copy.healthKitData = data
      copy.baselineZ?[metric] = nil
      copy.baselineSlope?[metric] = nil
      // Keep the means and ranges (the recent history hasn't changed) but
      // re-derive the deltas from the new value so the what-if stays coherent.
      if var statistics = copy.healthWindowStatistics?[metric] {
        statistics.delta24h = statistics.mean24h.map({ value - $0 })
        statistics.delta6h = statistics.delta6h == nil ? nil : statistics.mean24h.map({ value - $0 })
        copy.healthWindowStatistics?[metric] = statistics
      }

    case .weather(let field):
      guard let weather = copy.weatherStatistics else {
        return copy
      }
      if var statistics = copy.weatherWindowStatistics?[field] {
        statistics.delta24h = statistics.mean24h.map({ value - $0 })
        statistics.delta6h = statistics.delta6h == nil ? nil : statistics.mean24h.map({ value - $0 })
        copy.weatherWindowStatistics?[field] = statistics
      }
      copy.weatherStatistics = WeatherStatistics(
        barometricPressure: field == .devicePressure ? value : weather.barometricPressure,
        currentPressure: field == .currentPressure ? value : weather.currentPressure,
        currentHumidity: field == .humidity ? value : weather.currentHumidity,
        currentTemperature: field == .temperature ? value : weather.currentTemperature,
        sigmaPressure: field == .sigmaPressure ? value : weather.sigmaPressure,
        sigmaHumidity: field == .sigmaHumidity ? value : weather.sigmaHumidity,
        sigmaTemperature: field == .sigmaTemperature ? value : weather.sigmaTemperature)
    }

    return copy
  }

}
