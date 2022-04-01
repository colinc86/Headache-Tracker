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
  
  /// The application's background refresher.
  var refresher = Refresher()
  
  /// The application's headache manager.
  var headacheManager = HeadacheManager()
  
  // MARK: Private properties
  
  /// The app's previous brightness setting.
  private var previousBrightness: CGFloat = 0.0
  
  // Preferences
  let generalPreferences = Preferences.General()
  let healthPreferences = Preferences.Health()
  
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
    
    // Set up the refresh tasks
    refresher.setupPredictionRefreshTask()
    refresher.setupOutlookRefreshTask()
    refresher.setupTrainingProcessingTask()
    
    // Make sure the headache manager has a reference to the alert and health kit managers
    setHeadacheManagerReferences()
    
    // Check our location authorization status
    headacheManager.locationManager.setup()
    
    // Set up the async stuff
    Task {
      do {
        // Check our alert authorization status
        try await checkAlertAuthorizationStatus()
        
        // Check our health kit authorization status
        try await checkHealthKitAuthorizationStatus()
        
        // Load our ML classifiers
        try await headacheManager.predictor.load()
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
  
  /// Dims the screen given the new screen dimming value.
  ///
  /// - Parameter newValue: The new dimming value.
  func dimScreenChanged(_ newValue: Bool) {
    if newValue {
      dimScreen(preservingBrightness: true)
    }
    else {
      restoreScreenBrightness()
    }
  }
  
  func dimmingPercentChanged(_ newValue: Double) {
    dimScreen(preservingBrightness: false)
  }
  
  /// Dims the screen.
  func dimScreen(preservingBrightness: Bool) {
    if preservingBrightness {
      previousBrightness = UIScreen.main.brightness
    }
    
    UIScreen.main.wantsSoftwareDimming = true
    UIScreen.main.brightness = previousBrightness * (1.0 - CGFloat(generalPreferences.screenDimPercent))
  }
  
  /// Restores the screen to the previous brightness.
  func restoreScreenBrightness() {
    UIScreen.main.brightness = previousBrightness
    UIScreen.main.wantsSoftwareDimming = false
  }
  
}

// MARK: Private methods

extension AppDelegate {
  
  /// Sets up the manager's weak references.
  private func setHeadacheManagerReferences() {
    // Refresher
    refresher.headacheManager = headacheManager
  }
  
  /// Setup alerts.
  private func checkAlertAuthorizationStatus() async throws {
    if refresher.alertManager.authorizationStatus == .notDetermined {
      try await refresher.alertManager.setup(options: [.alert, .badge, .sound])
    }
  }
  
  /// Setup health kit (only if it hasn't been done before) and the setting
  /// is on.
  private func checkHealthKitAuthorizationStatus() async throws {
    if healthPreferences.enabled && headacheManager.healthKitManager.needsAuthorization() {
      try await headacheManager.healthKitManager.authorize()
    }
  }
  
}
