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
    appDelegate.headacheManager.cancelTrainingProcessingTask()
    appDelegate.headacheManager.cancelPredictionRefreshTask()
    appDelegate.headacheManager.cancelOutlookRefreshTask()
  }
  
  /// Called when the application resigns active.
  private func willResignActive(_ output: NotificationCenter.Publisher.Output) {
    logDebug("Application will resign active.")
    
    // Schedule our training and prediction tasks
    appDelegate.headacheManager.scheduleTrainingRefreshTask()
    appDelegate.headacheManager.schedulePredictionRefreshTask()
    
    // Schedule our outlook task
    if appDelegate.dailyOutlookAlerts {
      appDelegate.headacheManager.scheduleOutlookRefreshTask()
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
  
  /// The application's weather manager.
  var weatherManager = WeatherManager()
  
  /// Whether or not to enable crash reporting.
  @AppStorage(AppSettings.enableCrashReporting) var enableCrashReporting = true
    
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) var healthIntegration = false
  
  /// The real-time alerts setting.
  @AppStorage(AppSettings.realTimeAlerts) var realTimeAlerts = false
  
  /// The daily outlook alerts setting.
  @AppStorage(AppSettings.dailyOutlookAlerts) var dailyOutlookAlerts = false
  
  // MARK: Override methods
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    logDebug("Application did finish launching.")
    
    // Load firebase if we're not previewing
#if NON_PREVIEW
    FirebaseApp.configure()
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    
    Bugfender.activateLogger("EympFu86jcLlhHeq78zP5JouXlWE16Qu")
    Bugfender.enableCrashReporting()
    Bugfender.enableUIEventLogging()
    DDLog.add(DDBugfenderLogger.shared)
#else
    DDLog.add(DDOSLogger.sharedInstance)
    LoggingSystem.bootstrapWithCocoaLumberjack()
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
    
    // Check our location authorization status
    checkLocationAuthorizationStatus()
    
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
    headacheManager.weatherManager = weatherManager
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
  
  private func checkLocationAuthorizationStatus() {
    weatherManager.setup()
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
