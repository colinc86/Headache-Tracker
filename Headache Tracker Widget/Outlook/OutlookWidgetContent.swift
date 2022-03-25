//
//  OutlookWidgetContent.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import Foundation
import WidgetKit

struct OutlookWidgetContent: TimelineEntry {
  let date: Date
  let outlook: Outlook?
  let onset: Date?
  let duration: TimeInterval?
  let severity: Headache.Severity?
  let hasCurrentHeadache: Bool
  
  var holisticOutlook: HolisticOutlook {
    return HolisticOutlook(
      outlook: outlook ?? .noHeadache,
      onset: onset ?? Date(timeIntervalSinceNow: 86400.0),
      duration: duration ?? 0.0,
      severity: severity ?? .notPresent)
  }
}
