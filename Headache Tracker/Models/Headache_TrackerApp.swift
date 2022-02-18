//
//  Headache_TrackerApp.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import BackgroundTasks
import DataController
import Firebase
import Logger
import SwiftUI

@main
struct Headache_TrackerApp: App {
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) private var realTimeAlerts = false
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) private var learnAndPredict = false
  
  /// The application's headache manager.
  @StateObject var headacheManager = HeadacheManager()
  
  /// The application's health kit manager.
  @StateObject var healthKitManager = HealthKitManager()
  
  /// The application's headache predictor.
  @StateObject var headachePredictor = HeadachePredictor()
  
  /// The application's alert manager.
  @StateObject var alertManager = AlertManager()
  
  /// If this is the view's first appearance.
  @State var firstAppearance = true
  
  // Notification publishers
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  private let willResignActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
  
  // MARK: View body
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
        .environmentObject(headacheManager)
        .environmentObject(headachePredictor)
        .environmentObject(healthKitManager)
        .environmentObject(alertManager)
        .onAppear(perform: appeared)
        .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
        .onReceive(willResignActiveNotificationPublisher, perform: willResignActive)
    }
  }
  
}

// MARK: Action methods

extension Headache_TrackerApp {
  
  /// Called when the application becomes active.
  private func didBecomeActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application did become active.")
    headacheManager.cancelPredictionRefreshTask()
    headacheManager.cancelTrainingProcessingTask()
  }
  
  /// Called when the application resigns active.
  private func willResignActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application will resign active.")
    
    // Schedule our training task if we are learning and predicting
    if learnAndPredict {
      headacheManager.scheduleTrainingRefreshTask()
      
      // Schedule our prediction task if real-time alerts are on
      if realTimeAlerts {
        headacheManager.schedulePredictionRefreshTask()
      }
    }
  }
  
  /// Called when the application's view appears.
  private func appeared() {
    guard firstAppearance else {
      return
    }
    firstAppearance = false
    
    // Load firebase if we're not previewing
#if NON_PREVIEW
    FirebaseApp.configure()
#endif
    
    // Adjust the table view appearance
    UITableView.appearance().sectionFooterHeight = 0
    
    // Make sure we register our prediction task
    headacheManager.setupPredictionRefreshTask()
    headacheManager.setupTrainingProcessingTask()
    
    // Make sure the headache manager has a reference to the alert and health kit managers
    setHeadacheManagerReferences()
    
    // Check our alert authorization status
    checkAlertAuthorizationStatus()
    
    // Check our health kit authorization status
    checkHealthKitAuthorizationStatus()
    
    // Load our ML classifiers
    loadClassifiers()
  }
  
}

// MARK: Private methods

extension Headache_TrackerApp {
  
  /// Sets up the manager's weak references.
  private func setHeadacheManagerReferences() {
    headacheManager.alertManager = alertManager
    headacheManager.healthKitManager = healthKitManager
    headacheManager.headachePredictor = headachePredictor
  }
  
  /// Setup alerts.
  private func checkAlertAuthorizationStatus() {
    if alertManager.authorizationStatus == .notDetermined {
      alertManager.setup(options: [.alert, .badge, .sound], completion: nil)
    }
    else {
      alertManager.removeRequests(pending: false, delivered: true)
    }
  }
  
  /// Setup health kit (only if it hasn't been done before) and the setting
  /// is on.
  private func checkHealthKitAuthorizationStatus() {
    if healthIntegration && healthKitManager.needsAuthorization() {
      healthKitManager.authorize { error in
        if let error = error {
          logError("Error authorizing HealthKit: \(error)")
        }
      }
    }
  }
  
  /// Loads the ML classifiers and get's them ready for use.
  private func loadClassifiers() {
    headachePredictor.load { error in
      if let error = error {
        logError("Error loading classifiers: \(error)")
      }
      else {
        logDebug("Successfully loaded classifiers.")
      }
    }
  }
  
}
