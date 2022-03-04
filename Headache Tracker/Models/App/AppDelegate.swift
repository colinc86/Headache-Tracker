//
//  AppDelegate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/2/22.
//

@_exported import BugfenderSDK
import BackgroundTasks
import CocoaLumberjackSwift
import CocoaLumberjackSwiftLogBackend
import DataController
import Firebase
import Logging
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
  
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
#if NON_PREVIEW
    FirebaseApp.configure()
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    
    Bugfender.activateLogger(Constants.Bugfender.apiKey)
    Bugfender.enableCrashReporting()
    Bugfender.enableUIEventLogging()
    DDLog.add(DDBugfenderLogger.shared)
#else
    DDLog.add(DDOSLogger.sharedInstance)
    LoggingSystem.bootstrapWithCocoaLumberjack()
#endif
    
    logDebug("Application did finish launching.")
    
    // Adjust the table view appearance
    UITableView.appearance().sectionFooterHeight = 0
    
    // Make sure we register our tasks
    headacheManager.setupPredictionRefreshTask()
    headacheManager.setupOutlookRefreshTask()
    headacheManager.setupTrainingProcessingTask()
    
    // Make sure the headache manager has a reference to the alert and health kit managers
    setHeadacheManagerReferences()
    
    // Check our location authorization status
    checkLocationAuthorizationStatus()
    
    // Set up the async stuff
    Task {
      do {
        // Check our alert authorization status
        try await checkAlertAuthorizationStatus()
        
        // Check our health kit authorization status
        try await checkHealthKitAuthorizationStatus()
        
        // Load our ML classifiers
        try await loadClassifiers()
      }
      catch {
        logError("Error handling async process: \(error)")
      }
    }
    
    return true
  }
  
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let sceneConfiguration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    sceneConfiguration.delegateClass = SceneDelegate.self
    return sceneConfiguration
  }
  
}

// MARK: Public methods

extension AppDelegate {
  
  /// Checks for incomplete training data.
  func checkForIncompleteTrainingData() async throws {
    try await headacheManager.cleanTrainingData()
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
  private func checkAlertAuthorizationStatus() async throws {
    if alertManager.authorizationStatus == .notDetermined {
      try await alertManager.setup(options: [.alert, .badge, .sound])
    }
    else {
      alertManager.removeRequests(pending: false, delivered: true)
    }
  }
  
  /// Setup health kit (only if it hasn't been done before) and the setting
  /// is on.
  private func checkHealthKitAuthorizationStatus() async throws {
    if healthIntegration && healthKitManager.needsAuthorization() {
      try await healthKitManager.authorize()
    }
  }
  
  /// Checks for locationi authorization status.
  private func checkLocationAuthorizationStatus() {
    weatherManager.setup()
  }
  
  /// Loads the ML classifiers and get's them ready for use.
  private func loadClassifiers() async throws {
    try await predictor.load()
  }
  
}
