//
//  WidgetContent.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import WidgetKit

struct WidgetContent: TimelineEntry {
  var date = Date()
  let outlook: Outlook
  let onset: Date?
  let duration: TimeInterval?
}
