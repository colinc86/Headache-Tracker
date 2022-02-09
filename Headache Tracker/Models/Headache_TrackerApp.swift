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
  
  /// The application's headache manager.
  @StateObject var headacheManager = HeadacheManager()
  
  /// The application's alert manager.
  @StateObject var alertManager = AlertManager()
  
  // MARK: View body
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
        .environmentObject(headacheManager)
        .environmentObject(alertManager)
        .onAppear(perform: appeared)
    }
  }
  
}

// MARK: Private methods

extension Headache_TrackerApp {
  
  /// Called when the application's view appears.
  private func appeared() {
    // Make sure the headache manager has a reference to the alert manager
    headacheManager.alertManager = alertManager
    
    // Check our authorization status
    if alertManager.authorizationStatus == .notDetermined {
      alertManager.setup(options: [.alert, .badge, .sound], completion: nil)
    }
    else {
      alertManager.removeRequests(pending: false, delivered: true)
    }
  }
  
}
