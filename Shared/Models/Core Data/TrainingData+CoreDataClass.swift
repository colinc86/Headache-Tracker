//
//  TrainingData+CoreDataClass.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import Foundation
import CoreData

/// What created a training row. Rows are sampled when the app is used as
/// well as on a clock, and usage tracks headaches; the source lets that
/// density be audited and lets user-action rows be deduplicated.
enum TrainingDataSource: Int16, CaseIterable {

  /// A row written before sources were recorded.
  case unknown = 0

  /// A severity change, resolve, or "no headache" tap.
  case userAction = 1

  /// The app coming to the foreground with a stale last row.
  case foreground = 2

  /// The hourly background refresh.
  case background = 3

  /// A row written for a past timestamp (a back-logged headache or severity).
  case backdated = 4

  /// A title suitable for the user interface.
  var title: String {
    switch self {
    case .unknown: return "Unknown"
    case .userAction: return "User action"
    case .foreground: return "Foreground"
    case .background: return "Background"
    case .backdated: return "Backdated"
    }
  }

}

@objc(TrainingData)
public class TrainingData: NSManagedObject {

  /// The typed view of the stored `source` attribute.
  var sourceKind: TrainingDataSource {
    get { return TrainingDataSource(rawValue: source) ?? .unknown }
    set { source = newValue.rawValue }
  }

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
