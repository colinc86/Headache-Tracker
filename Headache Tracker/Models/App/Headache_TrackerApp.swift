//
//  Headache_TrackerApp.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

@_exported import BugfenderSDK
import BackgroundTasks
import CocoaLumberjackSwift
import CocoaLumberjackSwiftLogBackend
import DataController
import Firebase
import Logging
import SwiftUI

@main
struct Headache_TrackerApp: App {
  
  /// The application delegate.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  /// The application did become active publisher.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  /// The application will resign active publisher.
  private let willResignActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
  
  // MARK: View body
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        // Configure the view
        .accentColor(AppSettings.shared.general.colorTheme.baseColor)
      
        // Set the environment values
        .environment(\.debugSettings, AppSettings.shared.debug)
        .environment(\.generalSettings, AppSettings.shared.general)
        .environment(\.headacheSettings, AppSettings.shared.headaches)
        .environment(\.healthSettings, AppSettings.shared.health)
        .environment(\.listSettings, AppSettings.shared.lists)
        .environment(\.notificationSettings, AppSettings.shared.notifications)
        .environment(\.filterSettings, AppSettings.shared.filters)
        .environment(\.predictionSettings, AppSettings.shared.predictions)
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
        .onChange(of: AppSettings.shared.general.shouldDimScreen, perform: appDelegate.dimScreenChanged)
        .onChange(of: AppSettings.shared.general.screenDimPercent, perform: appDelegate.dimmingPercentChanged)
    }
  }
  
}

extension Headache_TrackerApp {
  
  /// Called when the application becomes active.
  private func didBecomeActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application did become active.")
    if AppSettings.shared.general.shouldDimScreen {
      appDelegate.dimScreen(preservingBrightness: true)
    }
    
    appDelegate.refresher.cancelTrainingProcessingTask()
    appDelegate.refresher.cancelPredictionRefreshTask()
    appDelegate.refresher.cancelOutlookRefreshTask()
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
    if AppSettings.shared.general.shouldDimScreen {
      appDelegate.restoreScreenBrightness()
    }
    
    // Schedule our training and prediction tasks
    Task {
      do {
        try await appDelegate.refresher.scheduleTrainingRefreshTask()
        try await appDelegate.refresher.schedulePredictionRefreshTask()
        
        // Schedule our outlook task
        if AppSettings.shared.notifications.dailyOutlookAlerts {
          try await appDelegate.refresher.scheduleOutlookRefreshTask()
        }
      }
      catch {
        logError("Error scheduling task: \(error)")
      }
    }
  }
  
  
  
}
