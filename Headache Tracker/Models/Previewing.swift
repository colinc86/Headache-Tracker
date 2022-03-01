//
//  Previewing.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import DataController
import Foundation
import SwiftUI
import HealthKit

struct Previewing {
  
  /// The preview headache manager.
  static let headacheManager = HeadacheManager(testing: true)
  
  /// The preview alert manager.
  static let alertManager = AlertManager()
  
  /// The preview health kit manager.
  static let healthKitManager = HealthKitManager()
  
  /// The preview predictor.
  static let predictor = Predictor()
  
  struct CoreData {
    
    /// The preview data controller.
    static let controller = DataController(containerName: "Headache_Tracker", inMemory: true)
    
    /// A headache.
    static var headache: Headache = {
      let now = Date()
      let headache = Headache(context: controller.container.viewContext, initialSeverity: .mild, startTime: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, startTime: now.addingTimeInterval(-2400.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-1200.0))
      headache.addSeverity(.notPresent, startTime: now.addingTimeInterval(-600.0))
      
      do {
        try controller.container.viewContext.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }()
    
    /// An unresolved headache.
    static var unresolvedHeadache: Headache = {
      let now = Date()
      let headache = Headache(context: controller.container.viewContext, initialSeverity: .mild, startTime: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, startTime: now.addingTimeInterval(-2400.0))
      
      do {
        try controller.container.viewContext.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }()
    
    /// A severity.
    static var severity: Severity = {
      return headache.severitiesArray.first!
    }()
    
    /// Sets up the preview objects.
    static func setupObjects() {
      logDebug("Setting up resolved headache with identifier \(headache.identifier?.uuidString ?? "N/A")")
      logDebug("Setting up unresolved headache with identifier \(unresolvedHeadache.identifier?.uuidString ?? "N/A")")
    }
    
  }
  
}
