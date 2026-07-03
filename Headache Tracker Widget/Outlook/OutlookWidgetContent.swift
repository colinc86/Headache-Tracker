//
//  OutlookWidgetContent.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import Foundation
import WidgetKit

struct OutlookWidgetContent: TimelineEntry {

  /// The entry's date.
  let date: Date

  /// The cached risk prediction, when one exists.
  let risk: RiskPrediction?

  /// The logged current severity, when a headache is in progress.
  let currentSeverity: Headache.Severity?

  /// The current headache's start time, for the elapsed display.
  let headacheStart: Date?

  /// Whether a headache is in progress.
  var hasCurrentHeadache: Bool {
    return currentSeverity != nil && currentSeverity != Headache.Severity.notPresent
  }

}
