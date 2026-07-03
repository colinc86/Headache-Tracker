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

  /// Exposure counts by kind title, most logged first.
  let exposureCounts: [(title: String, count: Int)]

  /// The strongest correlation insights.
  let insights: [InsightSummary]

}

extension ClinicianReportData {

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
        headacheDays.insert(calendar.startOfDay(for: start))
        totalDuration += headache.duration
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

      // Exposures over the same interval.
      let exposureRequest = Exposure.fetchRequest()
      exposureRequest.predicate = NSPredicate(format: "(timestamp >= %@) AND (timestamp <= %@)", interval.start as NSDate, interval.end as NSDate)
      var exposureTallies = [String: Int]()
      for exposure in try context.fetch(exposureRequest) {
        guard let kind = exposure.kindRaw else {
          continue
        }
        let title = ExposureKind(rawValue: kind)?.title ?? kind.capitalized
        exposureTallies[title, default: 0] += 1
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
        averageDuration: rows.isEmpty ? 0.0 : totalDuration / Double(rows.count),
        rows: rows,
        monthlyCounts: monthly.map({ MonthlyCount(month: $0.key, count: $0.value) }).sorted(by: { $0.month < $1.month }),
        severityCounts: severities.map({ SeverityCount(severity: $0.key, count: $0.value) }).sorted(by: { $0.severity.orderingValue < $1.severity.orderingValue }),
        medications: byName.values.map({ MedicationSummary(name: $0.name, count: $0.count, helpfulCount: $0.helpful, ratedCount: $0.rated) }).sorted(by: { $0.count > $1.count }),
        exposureCounts: exposureTallies.map({ (title: $0.key, count: $0.value) }).sorted(by: { $0.count > $1.count }),
        insights: Array(insights))
    }
  }

}
