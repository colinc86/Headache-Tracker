//
//  OutlookWidgetProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/1/22.
//

import WidgetKit
import SwiftUI

struct OutlookWidgetProvider: TimelineProvider {
  
  static let placeholder = OutlookWidgetContent(date: Date(), outlook: .noHeadache, onset: nil, duration: nil, severity: nil)
  
  let headacheManager = HeadacheManager()
  let predictor: Predictor = {
    let predictor = Predictor()
    Task {
      do {
        try await predictor.load()
      }
      catch {
        logError("Error loading predictor models: \(error)")
      }
    }
    return predictor
  }()
  
  func placeholder(in context: Context) -> OutlookWidgetContent {
    OutlookWidgetProvider.placeholder
  }
  
  func getSnapshot(in context: Context, completion: @escaping (OutlookWidgetContent) -> ()) {
    if context.isPreview {
      completion(placeholder(in: context))
    }
    else {
      completion(currentContent())
    }
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<OutlookWidgetContent>) -> ()) {
    let now = Date()
    let currentContent = currentContent()
    
    if now.timeIntervalSince(currentContent.date) >= 600.0 && predictor.ready {
      // Get a new prediction
      Task {
        do {
          let input = try await headacheManager.getCurrentClassifierInput()
          let prediction = try await predictor.predict(input, reloadWidget: false)
          
          let now = Date()
          let newContent = OutlookWidgetContent(
            date: now,
            outlook: prediction.outlookClassifierOutput.prediction,
            onset: prediction.onsetRegressorOutput.prediction,
            duration: prediction.durationRegressorOutput.prediction,
            severity: prediction.severityClassifierOutput.prediction)
          
          let reloadDate = now.addingTimeInterval(600.0)
          completion(Timeline(entries: [newContent], policy: .after(reloadDate)))
        }
        catch {
          logError("Error getting prediction: \(error)")
          let reloadDate = currentContent.date.addingTimeInterval(600.0)
          completion(Timeline(entries: [currentContent], policy: .after(reloadDate)))
        }
        
      }
      let reloadDate = currentContent.date.addingTimeInterval(600.0)
      completion(Timeline(entries: [currentContent], policy: .after(reloadDate)))
    }
    else {
      let reloadDate = currentContent.date.addingTimeInterval(600.0)
      completion(Timeline(entries: [currentContent], policy: .after(reloadDate)))
    }
  }
  
}

extension OutlookWidgetProvider {
  
  /// The current outlook content.
  private func currentContent() -> OutlookWidgetContent {
    return OutlookWidgetContent(
      date: SharedUserDefaults.standard.predictionDate ?? Date(timeIntervalSinceNow: -600.0),
      outlook: SharedUserDefaults.standard.predictedOutlook ?? .noHeadache,
      onset: SharedUserDefaults.standard.predictedOnset,
      duration: SharedUserDefaults.standard.predictedDuration,
      severity: SharedUserDefaults.standard.predictedSeverity
    )
  }
  
}
