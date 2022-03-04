//
//  Previewing.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
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
    static let controller: DataController = {
      let controller = DataController(containerName: "Headache_Tracker", inMemory: true)
      resolvedHeadache = addResolvedHeadache(to: controller.container.viewContext)
      unresolvedHeadache = addUnresolvedHeadache(to: controller.container.viewContext)
      return controller
    }()
      
    
    /// A resolved headache.
    static var resolvedHeadache: Headache! = nil
    
    /// An unresolved headache.
    static var unresolvedHeadache: Headache! = nil
    
    /// A severity.
    static var severity: Severity = {
      return resolvedHeadache.severitiesArray.first!
    }()
    
    static func addResolvedHeadache(to context: NSManagedObjectContext) -> Headache {
      let now = Date()
      let headache = Headache(context: context, initialSeverity: .mild, startTime: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, startTime: now.addingTimeInterval(-2400.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-1200.0))
      headache.addSeverity(.notPresent, startTime: now.addingTimeInterval(-600.0))
      headache.resolved = true
      
      do {
        try context.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }
    
    static func addUnresolvedHeadache(to context: NSManagedObjectContext) -> Headache {
      let now = Date()
      let headache = Headache(context: context, initialSeverity: .mild, startTime: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, startTime: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, startTime: now.addingTimeInterval(-2400.0))
      headache.resolved = false
      
      do {
        try context.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }
    
  }
  
}
