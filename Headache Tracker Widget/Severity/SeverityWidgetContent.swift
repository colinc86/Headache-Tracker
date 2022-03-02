//
//  SeverityWidgetContent.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/2/22.
//

import WidgetKit
import HealthKit

struct SeverityWidgetContent: TimelineEntry {
  var date: Date
  let severity: HKCategoryValueSeverity?
}
