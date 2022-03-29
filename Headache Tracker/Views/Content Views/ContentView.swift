//
//  ContentView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import SwiftUI
import CoreData
import DataController

/// The main content view that contains the tab view.
struct ContentView: View {
  
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
      .environmentObject(SceneDelegate())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
