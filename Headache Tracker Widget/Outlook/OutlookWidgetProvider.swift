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
    manager.locationManager.setup()
    
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
          completion((try await currentContent()).first!)
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
        let firstDate = content.first!.date
        
        if now.timeIntervalSince(firstDate) >= 600.0 && headacheManager.predictor.ready && headacheManager.authorizedForWidgetUpdates {
          // Get a new prediction
          try await headacheManager.createPredict(create: false, inWidget: true)
          
          // Get the new content
          let newContent = try await currentContent()
          
          // Use new content
          if newContent.first!.hasCurrentHeadache {
            // Duration prediction in headache
            completion(Timeline(entries: newContent, policy: .atEnd))
          }
          else {
            // Reload on a future date
            let reloadDate = firstDate.addingTimeInterval(600.0)
            completion(Timeline(entries: newContent, policy: .after(reloadDate)))
          }
        }
        else {
          // Use old content
          if content.first!.hasCurrentHeadache {
            // Duration prediction in headache
            completion(Timeline(entries: content, policy: .atEnd))
          }
          else {
            // Reload on a future date
            let reloadDate = firstDate.addingTimeInterval(600.0)
            completion(Timeline(entries: content, policy: .after(reloadDate)))
          }
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
  private func currentContent() async throws -> [OutlookWidgetContent] {
    let headache = try await headacheManager.hasCurrentHeadache()
    let prediction = SharedUserDefaults.standard.currentPrediction ?? .empty
    
    if headache {
      // If we're in a current headache, then we'll want to add
      // 10 entries - one for each minute.
      var entries = [OutlookWidgetContent]()
      for i in 0 ..< 10 {
        // We're not in a headache, so use the single entry with a
        // future reload date.
        entries.append(OutlookWidgetContent(
          date: prediction.date.addingTimeInterval(TimeInterval(i) * 60.0),
          outlook: prediction.outlookClassifierOutput.prediction,
          onset: prediction.onsetRegressorOutput.prediction,
          duration: prediction.durationRegressorOutput.prediction - (TimeInterval(i) * 60.0),
          severity: prediction.severityClassifierOutput.prediction,
          hasCurrentHeadache: true
        ))
      }
      return entries
    }
    
    // We're not in a headache, so use the single entry with a
    // future reload date.
    return [OutlookWidgetContent(
      date: prediction.date,
      outlook: prediction.outlookClassifierOutput.prediction,
      onset: prediction.onsetRegressorOutput.prediction,
      duration: prediction.durationRegressorOutput.prediction,
      severity: prediction.severityClassifierOutput.prediction,
      hasCurrentHeadache: false
    )]
  }
  
}
