//
//  DataController+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import Foundation
import DataController

extension DataController {
  
  /// The shared data controller.
  static let shared: DataController = {
    let controller = DataController(containerName: "Headache_Tracker")
    
    Task {
      do {
        try await controller.loadPersistentStores()
      }
      catch {
        logError("Error loading persistent stores: \(error)")
      }
    }
    
    return controller
  }()
  
}
