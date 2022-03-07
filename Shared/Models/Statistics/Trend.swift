//
//  Trend.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import SwiftUI

enum Trend {
  case steady(valueA: Double, valueB: Double)
  case rising(valueA: Double, valueB: Double)
  case falling(valueA: Double, valueB: Double)
  
  static let empty = Trend.steady(valueA: 0.0, valueB: 0.0)
  
  /// Creates a new trend with the given values.
  /// - Parameters:
  ///   - valueA: The first value.
  ///   - valueB: The second value.
  ///   - steadyValue: The value to use if the trend is steady.
  ///   - tolerance: The tolerance to use when calculating if the trend is steady.
  init(_ valueA: Double, _ valueB: Double, _ steadyValue: Double? = nil, _ tolerance: Double = 0.0) {
    let percentDifference = abs(valueB - valueA) / valueA
    if percentDifference < tolerance {
      if let steadyValue = steadyValue {
        self = .steady(valueA: steadyValue, valueB: steadyValue)
      }
      else {
        self = .steady(valueA: valueA, valueB: valueB)
      }
    }
    else if valueA < valueB {
      self = .rising(valueA: valueA, valueB: valueB)
    }
    else {
      self = .falling(valueA: valueA, valueB: valueB)
    }
  }
  
  /// The system image to use with the trend.
  var systemImage: String {
    switch self {
    case .steady: return "arrow.forward"
    case .rising: return "arrow.up.right"
    case .falling: return "arrow.down.right"
    }
  }
  
  /// The foreground color to use with the trend.
  var foregroundColor: Color {
    switch self {
    case .steady: return .cyan
    case .rising: return .orange
    case .falling: return .mint
    }
  }
  
  /// Whether the trend represents a steady state.
  var isSteady: Bool {
    switch self {
    case .steady: return true
    default: return false
    }
  }
  
  /// The trend's first value.
  var valueA: Double {
    switch self {
    case .steady(let valueA, _),
         .rising(let valueA, _),
         .falling(let valueA, _):
      return valueA
    }
  }
  
  /// The trend's second value.
  var valueB: Double {
    switch self {
    case .steady(_, let valueB),
         .rising(_, let valueB),
         .falling(_, let valueB):
      return valueB
    }
  }
}
