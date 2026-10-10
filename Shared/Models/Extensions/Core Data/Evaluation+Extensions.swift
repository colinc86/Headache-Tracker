//
//  Evaluation+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import CoreData
import Foundation

extension Evaluation {

  /// Whether an onset actually followed within the forecast window, once
  /// resolved. Stored directly since model 2.5; rows resolved before that
  /// only recorded whether the forecast was *correct*, so their outcome is
  /// reconstructed from that flag and the threshold in force at the time.
  var actualOutcome: Bool? {
    get {
      switch actualOutcomeRaw {
      case 0: return false
      case 1: return true
      default: return resolved ? Evaluation.reconstructedOutcome(probability: predictedProbability, wasCorrect: outlook) : nil
      }
    }
    set {
      switch newValue {
      case .some(true): actualOutcomeRaw = 1
      case .some(false): actualOutcomeRaw = 0
      case .none: actualOutcomeRaw = -1
      }
    }
  }

  /// Reconstructs an outcome from a correctness flag: the recorded probability
  /// says what the forecast was, and correctness says whether reality agreed.
  ///
  /// - Parameters:
  ///   - probability: The recorded probability (negative when none).
  ///   - wasCorrect: Whether the forecast was scored correct.
  /// - Returns: The outcome, or nil without a probability.
  static func reconstructedOutcome(probability: Double, wasCorrect: Bool) -> Bool? {
    guard probability >= 0 else {
      return nil
    }
    let predictedPositive = probability >= RiskPrediction.RiskTier.evaluationPositiveThreshold
    return wasCorrect ? predictedPositive : !predictedPositive
  }

}
