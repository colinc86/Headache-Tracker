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

/// The main content view that contains the tab view.
struct ContentView: View {
  
  // MARK: View body
  
  var body: some View {
    TabView {
      CurrentHeadacheView()
        .tabItem {
          Label("Track", systemImage: "brain.head.profile")
        }
      
      AnalyzeView()
        .tabItem {
          Label("Analyze", systemImage: "chart.bar.xaxis")
        }
      
      HeadachesView()
        .tabItem {
          Label("Headaches", systemImage: "list.bullet")
        }
      
      SettingsView()
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
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
