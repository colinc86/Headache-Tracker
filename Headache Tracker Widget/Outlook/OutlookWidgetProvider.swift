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
        logError("Error loading predictor models: \(error)")
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
        logError("Error getting current content: \(error)")
        completion(placeholder(in: context))
      }
    }
    
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<OutlookWidgetContent>) -> ()) {
    Task {
      do {
        let now = Date()
        let currentContent = try await currentContent()
        
        if now.timeIntervalSince(currentContent.date) >= 600.0 && headacheManager.predictor.ready && headacheManager.weatherManager.authorizedForWidgetUpdates {
          // Get a new prediction
          let input = try await headacheManager.getCurrentClassifierInput()
          let prediction = try await headacheManager.predictor.predict(input, reloadWidget: false)
          
          let now = Date()
          let newContent = OutlookWidgetContent(
            date: now,
            outlook: prediction.outlookClassifierOutput.prediction,
            onset: prediction.onsetRegressorOutput.prediction,
            duration: prediction.durationRegressorOutput.prediction,
            severity: prediction.severityClassifierOutput.prediction,
            hasCurrentHeadache: try await headacheManager.hasCurrentHeadache())
          
          let reloadDate = now.addingTimeInterval(600.0)
          completion(Timeline(entries: [newContent], policy: .after(reloadDate)))
        }
        else {
          let reloadDate = currentContent.date.addingTimeInterval(600.0)
          completion(Timeline(entries: [currentContent], policy: .after(reloadDate)))
        }
      }
      catch {
        logError("Error getting current content: \(error)")
        let reloadDate = Date().addingTimeInterval(600.0)
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
