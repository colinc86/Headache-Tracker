//
//  RiskTimelineProvider.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation
import WidgetKit

/// A timeline entry carrying a risk snapshot.
struct RiskWidgetEntry: TimelineEntry {

  /// The entry's date.
  let date: Date

  /// The snapshot rendered at `date`.
  let snapshot: RiskSnapshot

}

/// The one provider behind every risk widget. It reads the shared forecast,
/// the current severity, the logged history, and the cached insights — never
/// the sensors or the model — and emits half-hourly entries for six hours so
/// the forecast's age (and the Risk Clock's hour labels) keep moving between
/// the app's reloads.
struct RiskTimelineProvider: TimelineProvider {

  /// The spacing between entries.
  static let entryInterval: TimeInterval = 30.0 * 60.0

  /// How far ahead a timeline reaches before WidgetKit asks again.
  static let timelineSpan: TimeInterval = 6.0 * 3600.0

  func placeholder(in context: Context) -> RiskWidgetEntry {
    let now = Date()
    return RiskWidgetEntry(date: now, snapshot: RiskSnapshot.Samples.placeholder(asOf: now))
  }

  func getSnapshot(in context: Context, completion: @escaping (RiskWidgetEntry) -> Void) {
    let now = Date()
    if context.isPreview {
      // The gallery shows a representative forecast, never the empty state.
      completion(RiskWidgetEntry(date: now, snapshot: RiskSnapshot.Samples.elevated(asOf: now)))
      return
    }

    Task {
      let snapshot = await WidgetDataSource.loadSnapshot(asOf: now)
      completion(RiskWidgetEntry(date: now, snapshot: snapshot))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RiskWidgetEntry>) -> Void) {
    let now = Date()
    Task {
      let base = await WidgetDataSource.loadSnapshot(asOf: now)
      let entries = stride(from: 0.0, to: RiskTimelineProvider.timelineSpan, by: RiskTimelineProvider.entryInterval).map { offset -> RiskWidgetEntry in
        let date = now.addingTimeInterval(offset)
        return RiskWidgetEntry(date: date, snapshot: base.advanced(to: date))
      }
      completion(Timeline(entries: entries, policy: .atEnd))
    }
  }

}
