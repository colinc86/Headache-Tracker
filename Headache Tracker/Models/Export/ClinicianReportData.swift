//
//  ClinicianReportData.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import DataController
import Foundation

/// The value-type snapshot a clinician report is rendered from. Built on
/// the background write context; only these value types cross to the
/// main-actor renderer.
struct ClinicianReportData {

  /// One logged headache.
  struct HeadacheRow: Identifiable {
    let id: UUID
    let start: Date
    let end: Date?
    let type: String
    let classification: String
    let peakSeverity: Headache.Severity
    let duration: TimeInterval
    let medications: [String]
    let notes: String
    let tags: [String]
  }

  /// A month's headache count.
  struct MonthlyCount: Identifiable {
    let month: Date
    let count: Int
    var id: Date { month }
  }

  /// A severity's share of headaches.
  struct SeverityCount: Identifiable {
    let severity: Headache.Severity
    let count: Int
    var id: Int { severity.rawValue }
  }

  /// A medication's usage and efficacy summary.
  struct MedicationSummary: Identifiable {
    let name: String
    let count: Int
    let helpfulCount: Int
    let ratedCount: Int
    var id: String { name }
  }

  /// A correlation insight summary line.
  struct InsightSummary: Identifiable {
    let description: String
    let coefficient: Double
    let confidence: String
    let explainedBy: String?
    var id: String { description }
  }

  /// The reported date interval.
  let interval: DateInterval

  /// When the report was generated.
  let generatedAt: Date

  /// The number of headaches in the interval.
  let headacheCount: Int

  /// The number of distinct days with a headache.
  let daysWithHeadache: Int

  /// The mean headache duration.
  let averageDuration: TimeInterval

  /// The headaches, newest first.
  let rows: [HeadacheRow]

  /// Headache counts by month.
  let monthlyCounts: [MonthlyCount]

  /// Headache counts by peak severity.
  let severityCounts: [SeverityCount]

  /// Medication usage summaries, most used first.
  let medications: [MedicationSummary]

  /// The strongest correlation insights.
  let insights: [InsightSummary]

}

extension ClinicianReportData {

  /// The start-of-day for every day a span touches, from `start` through `end`
  /// inclusive — so a multi-day headache contributes each of its days to the
  /// "days affected" tally, not just the day it began.
  ///
  /// - Parameters:
  ///   - start: The span's start.
  ///   - end: The span's end (clamped to `start` if earlier).
  ///   - calendar: The calendar to reckon days in.
  /// - Returns: The distinct start-of-day dates the span covers.
  static func spannedDays(from start: Date, through end: Date, calendar: Calendar = .current) -> [Date] {
    var days = [Date]()
    var day = calendar.startOfDay(for: start)
    let lastDay = calendar.startOfDay(for: max(end, start))
    while day <= lastDay {
      days.append(day)
      day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400.0)
    }
    return days
  }

  /// Builds the report data for the given interval.
  ///
  /// - Parameter interval: The date interval to report on.
  /// - Returns: The report data.
  static func build(interval: DateInterval) async throws -> ClinicianReportData {
    // The cached insights report is read outside the context block.
    let insightsReport = InsightsStore.shared.load()

    return try await DataController.shared.performInBackground { context in
      // Headache.startTime is a computed property (first severity's start),
      // not a modeled attribute, so filter and sort in memory.
      let headaches = try context.fetch(Headache.fetchRequest())
        .filter { headache in
          guard let start = headache.startTime else {
            return false
          }
          return interval.contains(start)
        }
        .sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }

      let calendar = Calendar.current
      var rows = [HeadacheRow]()
      var monthly = [Date: Int]()
      var severities = [Headache.Severity: Int]()
      var headacheDays = Set<Date>()
      var totalDuration: TimeInterval = 0.0
      var resolvedCount = 0

      for headache in headaches {
        guard let start = headache.startTime else {
          continue
        }

        let peak = headache.severityRange.upperBound
        rows.append(HeadacheRow(
          id: headache.identifier ?? UUID(),
          start: start,
          end: headache.severitiesArray.last?.endTime,
          type: headache.headacheType.title,
          classification: headache.headacheClassification.title,
          peakSeverity: peak,
          duration: headache.duration,
          medications: headache.medicationsArray.compactMap({ $0.name }),
          notes: headache.notes ?? "",
          tags: headache.tagValues))

        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        monthly[month, default: 0] += 1
        severities[peak, default: 0] += 1

        // "Days affected" should count every day a headache was present, not
        // just the day it began — a multi-day migraine affects the patient on
        // each of those days. Clip the span to the report window (and to now,
        // via the interval end, for a still-unresolved headache).
        let end = min(headache.severitiesArray.last?.endTime ?? interval.end, interval.end)
        for day in ClinicianReportData.spannedDays(from: start, through: max(end, start), calendar: calendar) {
          headacheDays.insert(day)
        }

        // Average only completed headaches — an unresolved one's `duration` is
        // (now − start), an incomplete, ever-growing value that would skew the
        // clinical "average duration."
        if headache.endTime != nil {
          totalDuration += headache.duration
          resolvedCount += 1
        }
      }

      // Medications over the same interval.
      let medicationRequest = MedicationEntry.fetchRequest()
      medicationRequest.predicate = NSPredicate(format: "(takenAt >= %@) AND (takenAt <= %@)", interval.start as NSDate, interval.end as NSDate)
      let entries = try context.fetch(medicationRequest)

      var byName = [String: (name: String, count: Int, helpful: Int, rated: Int)]()
      for entry in entries {
        guard let name = entry.name else {
          continue
        }
        var summary = byName[name.lowercased()] ?? (name, 0, 0, 0)
        summary.count += 1
        if entry.efficacy != .unrated {
          summary.rated += 1
          if entry.efficacy == .helpful || entry.efficacy == .somewhatHelpful {
            summary.helpful += 1
          }
        }
        byName[name.lowercased()] = summary
      }

      let insights = (insightsReport?.insights ?? [])
        .filter({ $0.confidence != .suggestive })
        .prefix(6)
        .map { insight in
          InsightSummary(
            description: insight.directionDescription,
            coefficient: insight.coefficient,
            confidence: insight.confidence.title,
            explainedBy: insight.explainedBy?.title)
        }

      return ClinicianReportData(
        interval: interval,
        generatedAt: Date(),
        headacheCount: rows.count,
        daysWithHeadache: headacheDays.count,
        averageDuration: resolvedCount == 0 ? 0.0 : totalDuration / Double(resolvedCount),
        rows: rows,
        monthlyCounts: monthly.map({ MonthlyCount(month: $0.key, count: $0.value) }).sorted(by: { $0.month < $1.month }),
        severityCounts: severities.map({ SeverityCount(severity: $0.key, count: $0.value) }).sorted(by: { $0.severity.orderingValue < $1.severity.orderingValue }),
        // Deterministic tie-break (name/title) so regenerating the same report
        // doesn't reorder equal-count rows — `Dictionary.values` iteration order
        // and Swift's unstable sort are otherwise nondeterministic.
        medications: byName.values.map({ MedicationSummary(name: $0.name, count: $0.count, helpfulCount: $0.helpful, ratedCount: $0.rated) }).sorted(by: { $0.count != $1.count ? $0.count > $1.count : $0.name.lowercased() < $1.name.lowercased() }),
        insights: Array(insights))
    }
  }

}
