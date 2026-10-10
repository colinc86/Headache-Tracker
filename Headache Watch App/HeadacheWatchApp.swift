//
//  HeadacheWatchApp.swift
//  Headache Watch App
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI

@main
struct HeadacheWatchApp: App {

  init() {
    // Activate the connectivity session up front so wrist quick-logs reach
    // the phone even before the view appears.
    WatchConnectivityClient.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      WatchRiskView()
    }
  }

}
