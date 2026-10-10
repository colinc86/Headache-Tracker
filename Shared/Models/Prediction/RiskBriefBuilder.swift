//
//  RiskBriefBuilder.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation

/// A morning risk brief: the current tier plus plain-language reasons.
struct RiskBrief: Equatable {

  /// The risk tier.
  let tier: RiskPrediction.RiskTier

  /// The calibrated probability.
  let probability: Double

  /// Plain-language reasons, strongest first, at most three.
  let reasons: [String]

}

/// Builds the morning brief by comparing today's live feature values
/// against the user's baselines, filtered to features whose deviation
/// direction matches a confirmed insight.
struct RiskBriefBuilder {

  /// The minimum |z| for a deviation to count as a reason.
  static let minimumDeviation = 1.0

  /// Builds a brief.
  ///
  /// A reason is emitted only when the feature has a confident occurrence
  /// insight, today's value deviates at least one standard deviation from
  /// the user's baseline, and the deviation direction matches the insight's
  /// association (an unusually *low* value of a higher-is-worse trigger is
  /// not a reason).
  ///
  /// - Parameters:
  ///   - risk: The current risk prediction.
  ///   - todayValues: Today's live feature values.
  ///   - report: The latest insights report (for insights and baselines).
  /// - Returns: The brief, or nil when there's no usable prediction.
  static func makeBrief(risk: RiskPrediction?, todayValues: [CorrelationFeature: Double], report: InsightsReport?) -> RiskBrief? {
    guard let risk = risk, risk != .empty else {
      return nil
    }

    var reasons = [String]()

    if let report = report, let baselines = report.baselines {
      // Occurrence insights are already ranked strongest first.
      let insights = report.insights.filter({ $0.target == .occurrence && $0.explainedBy == nil })

      for insight in insights {
        guard reasons.count < 3 else {
          break
        }

        guard let value = todayValues[insight.feature],
              let baseline = baselines[insight.feature],
              baseline.std > 0 else {
          continue
        }

        let z = (value - baseline.mean) / baseline.std
        guard abs(z) >= Self.minimumDeviation else {
          continue
        }

        // The deviation must point the direction the insight associates
        // with headaches.
        let deviationElevated = z > 0
        guard deviationElevated == insight.higherIsAssociated else {
          continue
        }

        reasons.append("\(insight.feature.title) \(insight.feature.format(value)) vs. usual \(insight.feature.format(baseline.mean))")
      }
    }

    return RiskBrief(tier: risk.tier, probability: risk.probability, reasons: reasons)
  }

}

extension ModelInput {

  /// The input's live feature values keyed by correlation feature,
  /// mirroring `TrainingData.correlationSample` for in-memory inputs.
  func correlationValues() -> [CorrelationFeature: Double] {
    var values = [CorrelationFeature: Double]()

    if let healthKitData = healthKitData {
      for (key, value) in healthKitData {
        switch key {
        case .sleepSeconds: values[.sleepSeconds] = value
        case .sleepOnset:
          if value > 86400.0 {
            values[.sleepOnsetHour] = CorrelationFeature.hoursAfterSixPM(Date(timeIntervalSinceReferenceDate: value))
          }
        case .mindfulSession: values[.mindfulSeconds] = value
        case .stepCount: values[.stepCount] = value
        case .environmentalAudioExposure: values[.environmentalAudioExposure] = value
        case .headphoneAudioExposure: values[.headphoneAudioExposure] = value
        case .heartRate: values[.heartRate] = value
        case .restingHeartRate: values[.restingHeartRate] = value
        case .walkingHeartRateAverage: values[.walkingHeartRateAverage] = value
        case .heartRateVariabilitySDNN: values[.heartRateVariability] = value
        case .oxygenSaturation: values[.oxygenSaturation] = value
        case .respiratoryRate: values[.respiratoryRate] = value
        case .dietaryCaffeine: values[.dietaryCaffeine] = value
        case .dietaryWater: values[.dietaryWater] = value
        case .timeInDaylight: values[.timeInDaylight] = value
        case .appleExerciseTime: values[.exerciseMinutes] = value
        case .menstrualDaysSinceCycleStart: values[.menstrualDaysSinceCycleStart] = value
        case .menstrualFlowActive: values[.menstrualFlowActive] = value
        case .bodyTemperature: values[.bodyTemperature] = value
        case .wristTemperature: values[.wristTemperature] = value
        case .basalBodyTemperature: values[.basalBodyTemperature] = value
        case .hrvRMSSD: values[.hrvRMSSD] = value
        case .hrvPNN50: values[.hrvPNN50] = value
        case .hrvLFHF: values[.hrvLFHF] = value
        case .headache: break
        }
      }
    }

    if let weather = weatherStatistics {
      values[.pressure] = weather.currentPressure
      values[.humidity] = weather.currentHumidity
      values[.temperature] = weather.currentTemperature
      values[.sigmaPressure] = weather.sigmaPressure
      values[.sigmaHumidity] = weather.sigmaHumidity
      values[.sigmaTemperature] = weather.sigmaTemperature
      if let devicePressure = weather.barometricPressure {
        values[.devicePressure] = devicePressure
      }
    }

    return values
  }

}
