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
  
  /// The app's scene delegate.
  @EnvironmentObject private var sceneDelegate: SceneDelegate
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// The app's refresher.
  @EnvironmentObject private var refresher: Refresher

  /// The app's notification tap router.
  @EnvironmentObject private var router: Router

  var body: some View {
    TabView(selection: $router.selectedTab) {
      CurrentHeadacheView(
        headacheManager: headacheManager,
        predictor: predictor,
        refresher: refresher)
        .tabItem {
          Label("Track", systemImage: "brain.head.profile")
        }
        .tag(Router.Tab.track)
      
      AnalyzeView()
        .tabItem {
          Label("Analyze", systemImage: "chart.bar.xaxis")
        }
        .tag(Router.Tab.analyze)
      
      HeadachesView()
        .tabItem {
          Label("Headaches", systemImage: "list.bullet")
        }
        .tag(Router.Tab.headaches)
      
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
        .tag(Router.Tab.settings)
    }
  }
  
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(SceneDelegate())
      .environmentObject(Router())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Refresher())
      .environmentObject(Previewing.healthKitManager)
  }
}
