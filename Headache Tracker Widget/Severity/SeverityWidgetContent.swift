//
//  SeverityWidgetContent.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/2/22.
//

import WidgetKit

struct SeverityWidgetContent: TimelineEntry {
  let date = Date()
  let severity: Headache.Severity?
}
