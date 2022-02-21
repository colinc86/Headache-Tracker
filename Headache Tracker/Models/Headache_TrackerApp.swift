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
  
  /// The application delegate.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  // Notification publishers
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  private let willResignActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
  
  // MARK: View body
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
        .environmentObject(appDelegate.headacheManager)
        .environmentObject(appDelegate.predictor)
        .environmentObject(appDelegate.healthKitManager)
        .environmentObject(appDelegate.alertManager)
        .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
        .onReceive(willResignActiveNotificationPublisher, perform: willResignActive)
    }
  }
  
}

extension Headache_TrackerApp {
  
  /// Called when the application becomes active.
  private func didBecomeActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application did become active.")
  }
  
  /// Called when the application resigns active.
  private func willResignActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application will resign active.")
    
    // Schedule our training task if we are learning and predicting
    if appDelegate.learnAndPredict {
      appDelegate.headacheManager.scheduleTrainingRefreshTask()
      
      // Schedule our prediction task if real-time alerts are on
      if appDelegate.realTimeAlerts {
        appDelegate.headacheManager.schedulePredictionRefreshTask()
      }
      
      // Schedule our outlook task if real-time alerts are on
      if appDelegate.dailyOutlookAlerts {
        appDelegate.headacheManager.scheduleOutlookRefreshTask()
      }
    }
  }
  
}

class AppDelegate: NSObject, UIApplicationDelegate {
  
  // MARK: Public properties
  
  /// The application's headache manager.
  var headacheManager = HeadacheManager()
  
  /// The application's health kit manager.
  var healthKitManager = HealthKitManager()
  
  /// The application's headache predictor.
  var predictor = Predictor()
  
  /// The application's alert manager.
  var alertManager = AlertManager()
    
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) var healthIntegration = false
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) var dailyOutlookAlerts = false
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) var learnAndPredict = false
  
  // MARK: Override methods
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    logDebug("Application did finish launching.")
    
    // Load firebase if we're not previewing
#if NON_PREVIEW
    FirebaseApp.configure()
#endif
    
    // Adjust the table view appearance
    UITableView.appearance().sectionFooterHeight = 0
    
    // Make sure we register our tasks
    headacheManager.setupPredictionRefreshTask()
    headacheManager.setupOutlookRefreshTask()
    headacheManager.setupTrainingProcessingTask()
    
    // Make sure the headache manager has a reference to the alert and health kit managers
    setHeadacheManagerReferences()
    
    // Check our alert authorization status
    checkAlertAuthorizationStatus()
    
    // Check our health kit authorization status
    checkHealthKitAuthorizationStatus()
    
    // Load our ML classifiers
    loadClassifiers()
    
    return true
  }
  
}

// MARK: Private methods

extension AppDelegate {
  
  /// Sets up the manager's weak references.
  private func setHeadacheManagerReferences() {
    headacheManager.alertManager = alertManager
    headacheManager.healthKitManager = healthKitManager
    headacheManager.predictor = predictor
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
    predictor.load { error in
      if let error = error {
        logError("Error loading classifiers: \(error)")
      }
      else {
        logDebug("Successfully loaded classifiers.")
      }
    }
  }
  
}
