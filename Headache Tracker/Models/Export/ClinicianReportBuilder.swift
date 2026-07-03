//
//  ClinicianReportBuilder.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import CoreGraphics
import DataController
import Foundation
import SwiftUI

/// Renders clinician report data into shareable files.
struct ClinicianReportBuilder {

  /// US Letter in points.
  static let pageSize = CGSize(width: 612.0, height: 792.0)

  /// Log rows per PDF page.
  static let rowsPerPage = 20

  /// A report builder error.
  enum BuilderError: DescribableError {
    case pdfContext

    var description: String {
      switch self {
      case .pdfContext:
        return "Unable to create the PDF file."
      }
    }
  }

  // MARK: PDF

  /// Renders the report to a multi-page US-Letter PDF.
  ///
  /// `ImageRenderer` draws into a `CGPDFContext`, so text stays vector
  /// (selectable) and Swift Charts render natively.
  ///
  /// - Parameters:
  ///   - data: The report data.
  ///   - includeLog: Whether the paginated headache log is included.
  ///   - includeInsights: Whether the insights page is included.
  /// - Returns: The URL of the written PDF.
  @MainActor static func makePDF(data: ClinicianReportData, includeLog: Bool, includeInsights: Bool) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Headache Report.pdf")
    try? FileManager.default.removeItem(at: url)

    var mediaBox = CGRect(origin: .zero, size: Self.pageSize)
    guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
      throw BuilderError.pdfContext
    }

    var pages = [AnyView]()
    pages.append(AnyView(ReportSummaryPage(data: data)))

    if includeLog && !data.rows.isEmpty {
      let chunks = stride(from: 0, to: data.rows.count, by: Self.rowsPerPage).map { start in
        Array(data.rows[start ..< min(start + Self.rowsPerPage, data.rows.count)])
      }
      for (index, chunk) in chunks.enumerated() {
        pages.append(AnyView(ReportLogPage(rows: chunk, pageIndex: index + 1, pageCount: chunks.count)))
      }
    }

    if includeInsights {
      pages.append(AnyView(ReportInsightsPage(data: data)))
    }

    for page in pages {
      let renderer = ImageRenderer(content: ReportPageFrame { page })
      renderer.proposedSize = ProposedViewSize(Self.pageSize)
      renderer.render { _, render in
        pdf.beginPDFPage(nil)
        render(pdf)
        pdf.endPDFPage()
      }
    }

    pdf.closePDF()
    return url
  }

  // MARK: CSV

  /// Writes every severity interval in the report range to a CSV.
  ///
  /// - Parameter interval: The date interval to export.
  /// - Returns: The URL of the written CSV.
  static func makeCSV(interval: DateInterval) async throws -> URL {
    let formatter = ISO8601DateFormatter()

    let lines: [String] = try await DataController.shared.performInBackground { context in
      // Headache.startTime is a computed property (first severity's start),
      // not a modeled attribute, so filter and sort in memory.
      let headaches = try context.fetch(Headache.fetchRequest())
        .filter { headache in
          guard let start = headache.startTime else {
            return false
          }
          return interval.contains(start)
        }
        .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }

      var lines = ["headache_id,headache_start,type,classification,severity,severity_start,severity_end,medications,tags,notes"]
      for headache in headaches {
        guard let start = headache.startTime else {
          continue
        }

        let identifier = headache.identifier?.uuidString ?? ""
        let medications = headache.medicationsArray.compactMap({ $0.name }).joined(separator: "; ")
        let tags = headache.tagValues.joined(separator: "; ")
        let notes = headache.notes ?? ""

        for severity in headache.severitiesArray {
          let fields = [
            identifier,
            formatter.string(from: start),
            headache.headacheType.title,
            headache.headacheClassification.title,
            severity.severity.title,
            severity.startTime.map(formatter.string(from:)) ?? "",
            severity.endTime.map(formatter.string(from:)) ?? "",
            medications,
            tags,
            notes
          ]
          lines.append(fields.map(ClinicianReportBuilder.escaped).joined(separator: ","))
        }
      }
      return lines
    }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Headache Log.csv")
    try? FileManager.default.removeItem(at: url)
    try lines.joined(separator: "\r\n").write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  /// Escapes a CSV field per RFC 4180.
  ///
  /// - Parameter field: The raw field.
  /// - Returns: The escaped field.
  static func escaped(_ field: String) -> String {
    guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
      return field
    }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

}
