//
//  RiskFormat.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation

/// Formatting shared by the risk widgets and the risk Live Activity, so every
/// surface prints the same numbers the same way.
enum RiskFormat {

  /// A probability as a whole percent ("42%").
  static func percent(_ probability: Double) -> String {
    return "\(Int((probability * 100.0).rounded()))%"
  }

  /// A whole percent without the sign ("42 percent"), for accessibility.
  static func spokenPercent(_ probability: Double) -> String {
    return "\(Int((probability * 100.0).rounded())) percent"
  }

  /// A range as whole percents ("44–66%").
  static func range(_ interval: RiskInterval) -> String {
    return interval.rangeText
  }

  /// A spoken range ("likely between 44 and 66 percent").
  static func spokenRange(_ interval: RiskInterval) -> String {
    return interval.spokenText
  }

  /// A spoken range as its own sentence ("Likely between 44 and 66 percent").
  static func spokenRangeSentence(_ interval: RiskInterval) -> String {
    return interval.spokenText.prefix(1).uppercased() + interval.spokenText.dropFirst()
  }

  /// A signed whole percent ("+9%", "−3%").
  static func signedPercent(_ delta: Double) -> String {
    let value = Int((delta * 100.0).rounded())
    if value < 0 {
      return "−\(abs(value))%"
    }
    return "+\(value)%"
  }

  /// The tier's short word ("Low", "Elevated", "High").
  static func shortTier(_ tier: RiskPrediction.RiskTier) -> String {
    switch tier {
    case .low: return "Low"
    case .elevated: return "Elevated"
    case .high: return "High"
    }
  }

  /// A compact age ("25m ago", "3h ago", "2d ago").
  static func age(_ interval: TimeInterval) -> String {
    let seconds = max(interval, 0.0)
    if seconds < 60.0 {
      return "just now"
    }
    if seconds < 3600.0 {
      return "\(Int(seconds / 60.0))m ago"
    }
    if seconds < 86400.0 {
      return "\(Int(seconds / 3600.0))h ago"
    }
    return "\(Int(seconds / 86400.0))d ago"
  }

  /// A spoken age ("25 minutes ago").
  static func spokenAge(_ interval: TimeInterval) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(fromTimeInterval: -max(interval, 60.0))
  }

  /// A compact elapsed duration ("1h 20m", "45m", "2d 3h").
  static func elapsed(since start: Date, relativeTo now: Date = Date()) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    formatter.allowedUnits = now.timeIntervalSince(start) >= 86400.0 ? [.day, .hour] : [.hour, .minute]
    return formatter.string(from: max(now.timeIntervalSince(start), 60.0)) ?? "—"
  }

  /// An hour label for a clock tick ("3 PM").
  static func hourLabel(_ date: Date) -> String {
    return date.formatted(Date.FormatStyle().hour(.defaultDigits(amPM: .abbreviated)))
  }

}
