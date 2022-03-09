//
//  OutlookWidgetProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/1/22.
//

import CoreLocation
import WidgetKit
import SwiftUI

struct OutlookWidgetProvider: TimelineProvider {
  
  static let placeholder = OutlookWidgetContent(date: Date(), outlook: .noHeadache, onset: nil, duration: nil, severity: nil, hasCurrentHeadache: false)
  
  let headacheManager: HeadacheManager = {
    let manager = HeadacheManager()
    manager.weatherManager.setup()
    
    Task {
      do {
        try await manager.predictor.load()
      }
      catch {
        NSLog("Error loading predictor models: \(error)")
      }
    }
    return manager
  }()
  
  func placeholder(in context: Context) -> OutlookWidgetContent {
    OutlookWidgetProvider.placeholder
  }
  
  func getSnapshot(in context: Context, completion: @escaping (OutlookWidgetContent) -> ()) {
    Task {
      do {
        if context.isPreview {
          completion(placeholder(in: context))
        }
        else {
          completion(try await currentContent())
        }
      }
      catch {
        NSLog("Error getting current content: \(error)")
        completion(placeholder(in: context))
      }
    }
    
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<OutlookWidgetContent>) -> ()) {
    let now = Date()
    
    Task {
      do {
        let content = try await currentContent()
        
        if now.timeIntervalSince(content.date) >= 600.0 && headacheManager.predictor.ready && headacheManager.weatherManager.authorizedForWidgetUpdates {
          // Get a new prediction
          try await headacheManager.createPredict(create: false, inWidget: true)
          
          // Get the new content
          let newContent = try await currentContent()
          let reloadDate = newContent.date.addingTimeInterval(600.0)
          completion(Timeline(entries: [newContent], policy: .after(reloadDate)))
        }
        else {
          // Use old content
          let reloadDate = content.date.addingTimeInterval(600.0)
          completion(Timeline(entries: [content], policy: .after(reloadDate)))
        }
      }
      catch {
        NSLog("Error getting current content: \(error)")
              
        let reloadDate = now.addingTimeInterval(600.0)
        completion(Timeline(entries: [placeholder(in: context)], policy: .after(reloadDate)))
      }
    }
  }
  
}

extension OutlookWidgetProvider {
  
  /// The current outlook content.
  private func currentContent() async throws -> OutlookWidgetContent {
    return OutlookWidgetContent(
      date: SharedUserDefaults.standard.predictionDate ?? Date(timeIntervalSinceNow: -600.0),
      outlook: SharedUserDefaults.standard.predictedOutlook ?? .noHeadache,
      onset: SharedUserDefaults.standard.predictedOnset,
      duration: SharedUserDefaults.standard.predictedDuration,
      severity: SharedUserDefaults.standard.predictedSeverity,
      hasCurrentHeadache: try await headacheManager.hasCurrentHeadache()
    )
  }
  
}
