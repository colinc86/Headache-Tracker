//
//  ContentView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import SwiftUI
import CoreData
import DataController
import HealthKit
import Logger

/// The main content view that contains the tab view.
struct ContentView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The headache predictor.
  @EnvironmentObject private var headachePredictor: HeadachePredictor
  
  /// The health kit manager.
  @EnvironmentObject private var healthKitManager: HealthKitManager
  
  /// The alert manager for displaying notifications.
  @EnvironmentObject private var alertManager: AlertManager
  
  // MARK: View body
  
  var body: some View {
    TabView {
      CurrentHeadacheView()
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(headacheManager)
        .environmentObject(headachePredictor)
        .environmentObject(alertManager)
        .tabItem {
          Label("Track", systemImage: "brain.head.profile")
        }
      
      AnalyzeView()
        .environment(\.managedObjectContext, viewContext)
        .tabItem {
          Label("Analyze", systemImage: "chart.bar.xaxis")
        }
      
      HeadachesView()
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(headacheManager)
        .tabItem {
          Label("Headaches", systemImage: "list.bullet")
        }
      
      SettingsView()
        .environmentObject(headacheManager)
        .environmentObject(headachePredictor)
        .environmentObject(healthKitManager)
        .environmentObject(alertManager)
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
    }
  }
  
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.headachePredictor)
      .environmentObject(Previewing.healthKitManager)
      .onAppear {
        _ = Previewing.CoreData.headache
        _ = Previewing.CoreData.unresolvedHeadache
      }
  }
}
