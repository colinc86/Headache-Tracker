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
  
  enum TrainingTag {
    // A headache is possible later in the day.
    case outlookPossibleHeadache
    
    // A headache is in progress.
    case outlookHeadache
    
    // There is no headache later in the day.
    case outlookNoHeadache
  }
  
  // MARK: Volitile variables
  
  /// The time interval until the next headache begins.
  var timeIntervalUntilNextHeadacheStart: TimeInterval?
  
  /// The time interval until the current headache ends.
  var timeIntervalUntilNextHeadacheEnd: TimeInterval?
  
  /// The outlook training tag.
  var outlook: Outlook?
  
}
