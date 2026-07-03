//
//  InsightsStore.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/2/26.
//

import ApplicationKey
import Foundation

/// Caches the latest insights report as JSON in the app group container.
class InsightsStore {

  /// The shared store.
  static let shared = InsightsStore()

  // MARK: Private properties

  /// The in-memory cache of the latest report.
  private var cached: InsightsReport?

  /// The queue guarding the cache and file access.
  private let queue = DispatchQueue(label: ApplicationKey(from: "insightsStoreQueue"))

  /// The report file's URL in the app group container.
  private var fileURL: URL {
    let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return container.appendingPathComponent("insights.json")
  }

}

extension InsightsStore {

  /// Loads the latest report from cache or disk.
  ///
  /// - Returns: The report, or nil if none has been computed.
  func load() -> InsightsReport? {
    return queue.sync {
      if cached == nil, let data = try? Data(contentsOf: fileURL) {
        cached = try? JSONDecoder().decode(InsightsReport.self, from: data)
      }
      return cached
    }
  }

  /// Saves the report to cache and disk.
  ///
  /// - Parameter report: The report to save.
  func save(_ report: InsightsReport) {
    queue.sync {
      cached = report
      if let data = try? JSONEncoder().encode(report) {
        try? data.write(to: fileURL, options: .atomic)
      }
    }
  }

  /// Whether the report should be recomputed for the given row count.
  ///
  /// - Parameter rowCount: The current number of training data rows.
  /// - Returns: A boolean.
  func isStale(rowCount: Int) -> Bool {
    guard let report = load() else {
      return true
    }
    return report.rowCount != rowCount || Date().timeIntervalSince(report.generatedAt) > 86400.0
  }

}
