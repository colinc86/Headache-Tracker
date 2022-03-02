//
//  SeverityWidgetProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/2/22.
//

import WidgetKit
import SwiftUI

struct SeverityWidgetProvider: TimelineProvider {
  
  static let placeholder = SeverityWidgetContent(severity: nil)
  
  func placeholder(in context: Context) -> SeverityWidgetContent {
    SeverityWidgetProvider.placeholder
  }
  
  func getSnapshot(in context: Context, completion: @escaping (SeverityWidgetContent) -> ()) {
    completion(currentContent())
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<SeverityWidgetContent>) -> ()) {
    completion(Timeline(entries: [currentContent()], policy: .never))
  }
  
}

extension SeverityWidgetProvider {
  
  /// The current outlook content.
  private func currentContent() -> SeverityWidgetContent {
    return SeverityWidgetContent(severity: SharedUserDefaults.standard.currentSeverity)
  }
  
}
