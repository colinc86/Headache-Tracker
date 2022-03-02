//
//  OutlookWidgetProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/1/22.
//

import WidgetKit
import SwiftUI

struct OutlookWidgetProvider: TimelineProvider {
  
  static let placeholder = OutlookWidgetContent(date: Date().addingTimeInterval(60.0), outlook: .noHeadache, onset: nil, duration: nil, severity: nil)
  
  func placeholder(in context: Context) -> OutlookWidgetContent {
    OutlookWidgetProvider.placeholder
  }
  
  func getSnapshot(in context: Context, completion: @escaping (OutlookWidgetContent) -> ()) {
    completion(currentContent())
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<OutlookWidgetContent>) -> ()) {
    completion(Timeline(entries: [currentContent()], policy: .atEnd))
  }
  
}

extension OutlookWidgetProvider {
  
  /// The current outlook content.
  private func currentContent() -> OutlookWidgetContent {
    return OutlookWidgetContent(
      date: Date().addingTimeInterval(60.0),
      outlook: SharedUserDefaults.standard.predictedOutlook ?? .noHeadache,
      onset: SharedUserDefaults.standard.predictedOnset,
      duration: SharedUserDefaults.standard.predictedDuration,
      severity: SharedUserDefaults.standard.predictedSeverity
    )
  }
  
}
