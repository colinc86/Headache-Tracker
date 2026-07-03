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

  static let placeholder = OutlookWidgetContent(date: Date(), risk: nil, currentSeverity: nil, headacheStart: nil)
  let preferences = Preferences.Shared()

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
        var content = try await currentContent()

        let riskAge = now.timeIntervalSince(content.risk?.computedAt ?? .distantPast)
        if riskAge >= 600.0 && headacheManager.predictor.ready && headacheManager.authorizedForWidgetUpdates {
          // Get a new prediction and content
          try await headacheManager.createPredict(create: false, inWidget: true)
          content = try await currentContent()
        }

        // A single entry suffices: the active-headache elapsed display uses
        // a self-updating relative text style.
        let reloadDate = now.addingTimeInterval(600.0)
        completion(Timeline(entries: [content], policy: .after(reloadDate)))
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
    let currentSeverity: Headache.Severity? = preferences.currentSeverity
    let headacheStart = try await headacheManager.currentHeadacheStart()

    return OutlookWidgetContent(
      date: Date(),
      risk: preferences.currentRisk,
      currentSeverity: currentSeverity,
      headacheStart: headacheStart)
  }

}
