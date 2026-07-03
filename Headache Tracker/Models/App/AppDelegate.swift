//
//  AppDelegate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/2/22.
//

import BackgroundTasks
import CocoaLumberjackSwift
import CocoaLumberjackSwiftLogBackend
import DataController
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
  
  /// The app's preferences.
  private let preferences = Preferences()
  
  // MARK: Override methods
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
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
        // The models' feature schema changed (circular time encoding,
        // separate device pressure); models trained on the old schema can't
        // serve the new features, and old evaluations scored a different
        // methodology. Reset both once.
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: Constants.modelSchemaVersionKey) < Constants.modelSchemaVersion {
          logInfo("Model schema changed; resetting models and evaluations.")
          headacheManager.predictor.reset()
          try await headacheManager.resetEvaluation()
          defaults.set(Constants.modelSchemaVersion, forKey: Constants.modelSchemaVersionKey)
        }

        // Repair any data integrity issues from earlier versions
        try await headacheManager.repairDataIntegrity()

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
    UIScreen.main.brightness = previousBrightness * (1.0 - CGFloat(preferences.general.screenDimPercent))
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
    if preferences.health.enabled && headacheManager.healthKitManager.needsAuthorization() {
      try await headacheManager.healthKitManager.authorize()
    }
  }
  
}
