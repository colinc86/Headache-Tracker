//
//  Previewing.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import CoreData
import CoreLocation
import DataController
import Foundation
import SwiftUI

struct Previewing {
  
  /// The preview headache manager.
  static let headacheManager = HeadacheManager()
  
  /// The preview health kit manager.
  static let healthKitManager = HealthKitManager()
  
  /// A false value.
  @State static var booleanFalseValue: Bool = false
  
  /// A true value.
  @State static var booleanTrueValue: Bool = true
  
  /// A test loction.
  static var location: CLLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 32.781334, longitude: -96.778609), altitude: 139.0, horizontalAccuracy: 1000.0, verticalAccuracy: 10.0, timestamp: Date())
  
  /// Test weather statistics.
  static var weatherStatistics = WeatherStatistics(barometricPressure: 1000.0, currentPressure: 1000.0, currentHumidity: 0.8, currentTemperature: 50.0, sigmaPressure: 0.3, sigmaHumidity: 0.01, sigmaTemperature: 2.0)
  
  /// Test health kit data.
  static var healthKitData: [HealthKitData: Double] = [
    .heartRate: 70.0,
  ]
  
  struct Prediction {
    
    /// The preview predictor.
    static let predictor = Predictor()
    
    /// The preview prediction.
    static let prediction = RiskPrediction(
      input: .empty,
      probability: 0.42,
      topFactors: [
        RiskPrediction.RiskFactor(feature: .sleepSeconds, mlFeatureName: "Sleep Seconds", direction: .reduced, contributionDescription: "Lower sleep duration before headaches"),
        RiskPrediction.RiskFactor(feature: .sigmaPressure, mlFeatureName: "Sigma Pressure", direction: .elevated, contributionDescription: "Higher pressure change before headaches")
      ],
      computedAt: Date())
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
    static var severity: SeverityState = {
      return resolvedHeadache.severitiesArray.first!
    }()
    
    /// The preview data controller.
    private static let controller: DataController = DataController(containerName: "Headache_Tracker", inMemory: true)
    
    private static var _resolvedHeadache: Headache? = nil
    private static func addResolvedHeadache(to context: NSManagedObjectContext) -> Headache {
      let now = Date()
      let headache = Headache(context: context, severity: .mild, classification: .primary, type: .cluster, start: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, start: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, start: now.addingTimeInterval(-2400.0))
      headache.addSeverity(.moderate, start: now.addingTimeInterval(-1200.0))
      headache.addSeverity(.notPresent, start: now.addingTimeInterval(-600.0))
      
      let tagA = Tag(context: context)
      tagA.value = "headache"
      headache.addToTags(tagA)
      
      let tagB = Tag(context: context)
      tagB.value = "right"
      headache.addToTags(tagB)
      
      headache.resolved = true
      
      for _ in headache.severitiesArray {
        _ = createTrainingData(in: context)
      }
      
      do {
        try context.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }
    
    private static var _unresolvedHeadache: Headache? = nil
    private static func addUnresolvedHeadache(to context: NSManagedObjectContext) -> Headache {
      let now = Date()
      let headache = Headache(context: context, severity: .mild, classification: .primary, type: .cluster, start: now.addingTimeInterval(-3600.0))
      headache.addSeverity(.moderate, start: now.addingTimeInterval(-3000.0))
      headache.addSeverity(.severe, start: now.addingTimeInterval(-2400.0))
      headache.resolved = false
      
      for _ in headache.severitiesArray {
        _ = createTrainingData(in: context)
      }
      
      let tagA = Tag(context: context)
      tagA.value = "another"
      
      let tagB = Tag(context: context)
      tagB.value = "left"
      
      do {
        try context.save()
      }
      catch {
        fatalError(error.localizedDescription)
      }
      
      return headache
    }
    
    private static func createTrainingData(in context: NSManagedObjectContext) -> TrainingData {
      let input = ModelInput(date: Date(), location: Previewing.location, weatherStatistics: Previewing.weatherStatistics, healthKitData: Previewing.healthKitData)
      return TrainingData(context: context, input: input)
    }
    
  }
  
}
