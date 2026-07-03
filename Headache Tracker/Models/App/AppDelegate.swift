//
//  AppDelegate.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/2/22.
//

import BackgroundTasks
import CocoaLumberjackSwift
import CocoaLumberjackSwiftLogBackend
import Combine
import DataController
import Logging
import SwiftUI
import UserNotifications
import WidgetKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
  
  // MARK: Public properties
  
  /// The application's background refresher.
  var refresher = Refresher()
  
  /// The application's headache manager.
  var headacheManager = HeadacheManager()

  /// The application's notification tap router.
  var router = Router()

  /// The application's notification delegate.
  let alertDelegate = AlertDelegate()
  
  // MARK: Private properties
  
  /// The app's previous brightness setting.
  private var previousBrightness: CGFloat = 0.0
  
  /// The app's preferences.
  private let preferences = Preferences()

  /// The remote store-change subscription (sync only).
  private var remoteChangeCancellable: AnyCancellable?

  /// Serializes remote-change handling so bursts of imports coalesce.
  private var remoteChangeTask: Task<Void, Never>?
  
  // MARK: Override methods
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    logDebug("Application did finish launching.")

    // Theme and units moved to the shared suite so widgets render with the
    // user's settings; migrate existing values from standard defaults once.
    if let shared = UserDefaults.shared {
      let keys = [Preferences.General.Keys.colorTheme, Preferences.General.Keys.measurementSystem]
      for key in keys where shared.object(forKey: key) == nil {
        if let value = UserDefaults.standard.object(forKey: key) {
          shared.set(value, forKey: key)
        }
      }
    }

    // Adjust the table view appearance
    UITableView.appearance().sectionFooterHeight = 0
    
    // Wire the notification delegate synchronously so a cold-start tap on a
    // notification is delivered to it
    alertDelegate.headacheManager = headacheManager
    alertDelegate.router = router
    UNUserNotificationCenter.current().delegate = alertDelegate
    alertDelegate.registerCategories(with: UNUserNotificationCenter.current())

    // Set up the refresh tasks
    refresher.setupPredictionRefreshTask()
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
          // The four-model era's shared prediction is orphaned; clear it.
          UserDefaults.shared?.removeObject(forKey: Preferences.Shared.Keys.legacyCurrentPrediction)
          defaults.set(Constants.modelSchemaVersion, forKey: Constants.modelSchemaVersionKey)
        }

        // One-time user-data migration into the cloud store, then start
        // observing remote changes. This must run before anything that can
        // throw for unrelated reasons (alert authorization), or the
        // migration could be skipped while the split layout is live.
        if preferences.sync.storeIsSplit {
          try await CloudMigrator.migrateIfNeeded()
          observeRemoteChanges()
        }

        // Repair any data integrity issues from earlier versions
        try await headacheManager.repairDataIntegrity()

        // Check our alert authorization status
        try await checkAlertAuthorizationStatus()

        // Check our health kit authorization status
        try await checkHealthKitAuthorizationStatus()

        // Load our ML classifiers
        try await headacheManager.predictor.load()

        // Keep the evening check-in reminder aligned with preferences.
        // Non-critical: scheduling throws when notifications are denied.
        do {
          try await refresher.updateExposureReminderSchedule()
        }
        catch {
          logError("Error scheduling check-in reminder: \(error)")
        }
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
  
  /// The active window scene's screen.
  private var screen: UIScreen? {
    return UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive })?.screen
      ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.screen
  }

  /// Dims the screen.
  func dimScreen(preservingBrightness: Bool) {
    guard let screen = screen else {
      return
    }

    if preservingBrightness {
      previousBrightness = screen.brightness
    }

    screen.wantsSoftwareDimming = true
    screen.brightness = previousBrightness * (1.0 - CGFloat(preferences.general.screenDimPercent))
  }

  /// Restores the screen to the previous brightness.
  func restoreScreenBrightness() {
    guard let screen = screen else {
      return
    }

    screen.brightness = previousBrightness
    screen.wantsSoftwareDimming = false
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

  /// Subscribes to remote store changes: after a CloudKit import (or a
  /// widget write), repair invariants, dedupe tags, and refresh the shared
  /// severity. Persistent history is deliberately NOT purged here — the
  /// CloudKit mirroring delegate consumes that history to export local
  /// changes, and purging it while a device is offline would silently drop
  /// unexported rows from sync.
  private func observeRemoteChanges() {
    remoteChangeCancellable = DataController.shared.remoteChangePublisher
      .debounce(for: .seconds(2.0), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }

        self.remoteChangeTask?.cancel()
        self.remoteChangeTask = Task {
          do {
            try await self.headacheManager.repairDataIntegrity()
            try await self.headacheManager.dedupeTags()
            try await self.headacheManager.refreshSharedState()
            WidgetCenter.shared.reloadAllTimelines()
          }
          catch {
            logError("Error handling remote change: \(error)")
          }
        }
      }
  }
  
}
