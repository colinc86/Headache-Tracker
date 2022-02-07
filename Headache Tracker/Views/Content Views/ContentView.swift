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

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject private var headacheManager: HeadacheManager
  @EnvironmentObject private var alertManager: AlertManager
    
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  @State var alertTitle = ""
  @State var alertMessage = ""
  @State var showingAlert = false
  @State var presentingSettings = false
  
  var body: some View {
    TabView {
      CurrentHeadacheView()
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(headacheManager)
        .environmentObject(alertManager)
        .tabItem {
          Label("Current Headache", systemImage: "brain.head.profile")
        }
      
      HeadachesView()
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(headacheManager)
        .tabItem {
          Label("Headaches", systemImage: "heart.text.square")
        }
      
      SettingsView()
        .environmentObject(headacheManager)
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
  }
}
