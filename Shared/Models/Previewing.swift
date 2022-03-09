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
  
  /// The preview health kit manager.
  static let healthKitManager = HealthKitManager()
  
  @State static var booleanFalseValue: Bool = false
  @State static var booleanTrueValue: Bool = true
  
  struct Prediction {
    
    /// The preview predictor.
    static let predictor = Predictor()
    
    /// The preview prediction.
    static let prediction = Predictor.Prediction()
    
  }
  
  struct CoreData {
    
    /// The view context to preview with.
    static var viewContext: NSManagedObjectContext {
      if _resolvedHeadache == nil {
        _resolvedHeadache = addResolvedHeadache(to: controller.container.viewContext)
      }
      if _unresolvedHeadache == nil {
        _unresolvedHeadache = addUnresolvedHeadache(to: controller.container.viewContext)
      }
      return controller.container.viewContext
    }
    
    /// A resolved headache.
    static var resolvedHeadache: Headache {
      if _resolvedHeadache == nil {
        _resolvedHeadache = addResolvedHeadache(to: controller.container.viewContext)
      }
      return _resolvedHeadache!
    }
  
    /// An unresolved headache.
    static var unresolvedHeadache: Headache {
      if _unresolvedHeadache == nil {
        _unresolvedHeadache = addUnresolvedHeadache(to: controller.container.viewContext)
      }
      return _unresolvedHeadache!
    }
    
    /// A severity.
    static var severity: Severity = {
      return resolvedHeadache.severitiesArray.first!
    }()
    
    /// The preview data controller.
    private static let controller: DataController = DataController(containerName: "Headache_Tracker", inMemory: true)
    private static var _resolvedHeadache: Headache? = nil
    private static var _unresolvedHeadache: Headache? = nil
    private static func addResolvedHeadache(to context: NSManagedObjectContext) -> Headache {
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
    
    private static func addUnresolvedHeadache(to context: NSManagedObjectContext) -> Headache {
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
