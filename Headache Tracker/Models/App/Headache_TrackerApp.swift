//
//  Headache_TrackerApp.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import BackgroundTasks
import CocoaLumberjackSwift
import CocoaLumberjackSwiftLogBackend
import DataController
import Logging
import SwiftUI

@main
struct Headache_TrackerApp: App {
  
  /// The application delegate.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  // Preferences
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  @AppStorage(Preferences.General.Keys.shouldDimScreen) var shouldDimScreen = false
  @AppStorage(Preferences.General.Keys.screenDimPercent) var screenDimPercent = 0.5
  
  /// The application did become active publisher.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  /// The application will resign active publisher.
  private let willResignActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
  
  // MARK: View body
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        // Configure the view
        .accentColor(colorTheme.baseColor)
      
        // Set the environment values
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
      
        // Set the environment objects
        .environmentObject(appDelegate.headacheManager)
        .environmentObject(appDelegate.headacheManager.predictor)
        .environmentObject(appDelegate.headacheManager.healthKitManager)
        .environmentObject(appDelegate.refresher.alertManager)
        .environmentObject(appDelegate.refresher)
      
        // Subscribe to notifications
        .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
        .onReceive(willResignActiveNotificationPublisher, perform: willResignActive)
        .onChange(of: shouldDimScreen) { _, newValue in appDelegate.dimScreenChanged(newValue) }
        .onChange(of: screenDimPercent) { _, newValue in appDelegate.dimmingPercentChanged(newValue) }
    }
  }
  
}

extension Headache_TrackerApp {
  
  /// Called when the application becomes active.
  private func didBecomeActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application did become active.")
    if shouldDimScreen {
      appDelegate.dimScreen(preservingBrightness: true)
    }
    
    appDelegate.refresher.cancelTrainingProcessingTask()
    appDelegate.refresher.cancelPredictionRefreshTask()
    appDelegate.refresher.alertManager.removeRequests(pending: false, delivered: true)
    
    Task {
      do {
        try await appDelegate.headacheManager.upgradeTrainingData()
      }
      catch {
        logError("Error checking for incomplete training data: \(error)")
      }
    }
  }
  
  /// Called when the application resigns active.
  private func willResignActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application will resign active.")
    if shouldDimScreen {
      appDelegate.restoreScreenBrightness()
    }
    
    // Schedule our training and prediction tasks. The prediction task also
    // presents the daily outlook alert when it's due.
    Task {
      do {
        try await appDelegate.refresher.scheduleTrainingRefreshTask()
        try await appDelegate.refresher.schedulePredictionRefreshTask()
      }
      catch {
        logError("Error scheduling task: \(error)")
      }
    }
  }

}
