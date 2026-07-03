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

  // MARK: Volitile variables

  /// The time interval until the next headache begins.
  var timeIntervalUntilNextHeadacheStart: TimeInterval?

  /// The time interval until the current headache ends.
  var timeIntervalUntilNextHeadacheEnd: TimeInterval?

  /// The outlook training tag.
  var outlook: Outlook?

  /// The severity derived from headache intervals at this row's timestamp.
  ///
  /// Derived labels survive headache edits and deletions, unlike the
  /// `severity` relationship, which is advisory provenance only.
  var derivedSeverity: Headache.Severity?

}
