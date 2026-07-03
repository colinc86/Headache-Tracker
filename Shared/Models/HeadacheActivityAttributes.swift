//
//  HeadacheActivityAttributes.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import ActivityKit
import Foundation

/// The Live Activity describing an in-progress headache.
struct HeadacheActivityAttributes: ActivityAttributes {

  /// The mutable state: the logged severity and when it last changed.
  struct ContentState: Codable, Hashable {

    /// The current severity's raw value.
    var severityRawValue: Int

    /// When the severity was last updated.
    var lastUpdate: Date

    /// The current severity.
    var severity: Headache.Severity {
      return Headache.Severity(rawValue: severityRawValue) ?? .unspecified
    }

  }

  /// The headache's start time. Attributes are immutable — an edited onset
  /// restarts the activity.
  let startDate: Date

}
