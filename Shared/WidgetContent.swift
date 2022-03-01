//
//  WidgetContent.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import WidgetKit
import HealthKit

struct WidgetContent: TimelineEntry {
  var date = Date()
  let outlook: Outlook?
  let onset: Date?
  let duration: TimeInterval?
  let severity: HKCategoryValueSeverity?
  
  var holisticOutlook: HolisticOutlook {
    return HolisticOutlook(
      outlook: outlook ?? .noHeadache,
      onset: onset ?? Date(timeIntervalSinceNow: 86400.0),
      duration: duration ?? 0.0,
      severity: severity ?? .notPresent)
  }
}
