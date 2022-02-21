//
//  TrainingData+CoreDataClass.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import Foundation
import CoreData

@objc(TrainingData)
public class TrainingData: NSManagedObject {
  
  var timeIntervalUntilNextHeadacheStart: TimeInterval?
  var timeIntervalUntilNextHeadacheEnd: TimeInterval?
  
}
