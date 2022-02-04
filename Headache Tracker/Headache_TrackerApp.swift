//
//  Headache_TrackerApp.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import SwiftUI

@main
struct Headache_TrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
