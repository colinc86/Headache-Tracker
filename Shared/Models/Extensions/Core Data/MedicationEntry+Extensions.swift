//
//  MedicationEntry+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import CoreData
import Foundation

extension MedicationEntry {

  /// How well a medication worked, as rated by the user.
  enum Efficacy: Int64, CaseIterable, Identifiable {
    case unrated = -1
    case notHelpful = 0
    case somewhatHelpful = 1
    case helpful = 2

    var id: Int64 {
      return rawValue
    }

    /// A title suitable for the user interface.
    var title: String {
      switch self {
      case .unrated: return "Unrated"
      case .notHelpful: return "Not Helpful"
      case .somewhatHelpful: return "Somewhat"
      case .helpful: return "Helpful"
      }
    }

    /// The system image to represent the efficacy.
    var systemImage: String {
      switch self {
      case .unrated: return "questionmark.circle"
      case .notHelpful: return "hand.thumbsdown"
      case .somewhatHelpful: return "hand.raised"
      case .helpful: return "hand.thumbsup"
      }
    }
  }

  /// The entry's efficacy.
  var efficacy: Efficacy {
    get { return Efficacy(rawValue: efficacyRaw) ?? .unrated }
    set { efficacyRaw = newValue.rawValue }
  }

  // MARK: Initializers

  /// Initializes a medication entry.
  ///
  /// - Parameters:
  ///   - context: The context to create the entry in.
  ///   - name: The medication's name.
  ///   - takenAt: When the medication was taken.
  convenience init(context: NSManagedObjectContext, name: String, takenAt: Date) {
    self.init(context: context)
    self.identifier = UUID()
    self.name = name
    self.takenAt = takenAt
    self.efficacyRaw = Efficacy.unrated.rawValue
  }

}

// MARK: Static methods

extension MedicationEntry {

  /// Creates a fetch request.
  ///
  /// - Parameter identifier: The entry's identifier.
  /// - Returns: A fetch request.
  static func fetchRequest(withIdentifier identifier: UUID) -> NSFetchRequest<MedicationEntry> {
    let request = MedicationEntry.fetchRequest()
    request.predicate = NSPredicate(format: "identifier = %@", identifier as NSUUID)
    return request
  }

}

extension Headache {

  /// Gets the headache's medication entries as a sorted array.
  var medicationsArray: [MedicationEntry] {
    return (medications?.sortedArray(using: [NSSortDescriptor(key: "takenAt", ascending: true)]) as? [MedicationEntry]) ?? []
  }

}
