//
//  OutlookWidgetProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/1/22.
//

import WidgetKit
import SwiftUI

struct OutlookWidgetProvider: TimelineProvider {
  
  static let placeholder = OutlookWidgetContent(outlook: .noHeadache, onset: nil, duration: nil, severity: nil)
  
  func placeholder(in context: Context) -> OutlookWidgetContent {
    OutlookWidgetProvider.placeholder
  }
  
  func getSnapshot(in context: Context, completion: @escaping (OutlookWidgetContent) -> ()) {
    completion(currentContent())
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<OutlookWidgetContent>) -> ()) {
    completion(Timeline(entries: [currentContent()], policy: .never))
  }
  
}

extension OutlookWidgetProvider {
  
  /// The current outlook content.
  private func currentContent() -> OutlookWidgetContent {
    return OutlookWidgetContent(
      outlook: SharedUserDefaults.standard.predictedOutlook ?? .noHeadache,
      onset: SharedUserDefaults.standard.predictedOnset,
      duration: SharedUserDefaults.standard.predictedDuration,
      severity: SharedUserDefaults.standard.predictedSeverity
    )
  }
  
}
