//
//  Headache_TrackerApp.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import SwiftUI
import DataController
import Logger

@main
struct Headache_TrackerApp: App {
  
  /// The Apple Health app integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
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
    }
  }
  
}

// MARK: Private methods

extension Headache_TrackerApp {
  
  /// Called when the application's view appears.
  private func appeared() {
    guard firstAppearance else {
      return
    }
    firstAppearance = false
    
    // Make sure the headache manager has a reference to the alert and health kit managers
    headacheManager.alertManager = alertManager
    headacheManager.healthKitManager = healthKitManager
    headacheManager.headachePredictor = headachePredictor
    
    // Check our alert authorization status
    if alertManager.authorizationStatus == .notDetermined {
      alertManager.setup(options: [.alert, .badge, .sound], completion: nil)
    }
    else {
      alertManager.removeRequests(pending: false, delivered: true)
    }
    
    // Check our health kit authorization status
    if healthIntegration && healthKitManager.needsAuthorization() {
      healthKitManager.authorize { error in
        if let error = error {
          logError("Error authorizing HealthKit: \(error)")
        }
      }
    }
    
    // Load our ML classifiers
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
