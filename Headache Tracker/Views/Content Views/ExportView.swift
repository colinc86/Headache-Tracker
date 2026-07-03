//
//  ExportView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Generates and shares the clinician report and raw CSV log.
struct ExportView: View {

  /// The report range presets.
  enum RangePreset: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case year
    case all

    var id: String { rawValue }

    var title: String {
      switch self {
      case .threeMonths: return "3 Months"
      case .sixMonths: return "6 Months"
      case .year: return "1 Year"
      case .all: return "All Time"
      }
    }

    /// The preset's date interval, ending now.
    var interval: DateInterval {
      let end = Date()
      switch self {
      case .threeMonths: return DateInterval(start: Calendar.current.date(byAdding: .month, value: -3, to: end) ?? end, end: end)
      case .sixMonths: return DateInterval(start: Calendar.current.date(byAdding: .month, value: -6, to: end) ?? end, end: end)
      case .year: return DateInterval(start: Calendar.current.date(byAdding: .year, value: -1, to: end) ?? end, end: end)
      case .all: return DateInterval(start: Date(timeIntervalSince1970: 0), end: end)
      }
    }
  }

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The selected range preset.
  @State private var range = RangePreset.sixMonths

  /// Whether the paginated log is included in the PDF.
  @State private var includeLog = true

  /// Whether the insights page is included in the PDF.
  @State private var includeInsights = true

  /// The generated file waiting to be exported.
  @State private var exportURL: URL?

  /// Whether the file exporter is presented.
  @State private var showingExporter = false

  /// The content type of the generated file.
  @State private var exportType = UTType.pdf

  // MARK: View body

  var body: some View {
    Form {
      Section {
        Picker("Range", selection: $range) {
          ForEach(RangePreset.allCases) { preset in
            Text(preset.title).tag(preset)
          }
        }
      } footer: {
        SectionFooterView(title: "The report covers headaches, medications, and exposures in this range.")
      }

      Section {
        Toggle("Headache Log", isOn: $includeLog)
          .tint(colorTheme.baseColor)
        Toggle("Patterns & Treatments", isOn: $includeInsights)
          .tint(colorTheme.baseColor)
      } header: {
        SectionTitleView(title: "Report Sections")
      }

      Section {
        AsyncButton("Generate PDF Report", mode: .replacingContent, action: generatePDF)
        AsyncButton("Export CSV Log", mode: .replacingContent, action: generateCSV)
      } footer: {
        SectionFooterView(title: "The PDF is a printable summary for your clinician. The CSV contains every logged severity interval for analysis elsewhere.")
      }
    }
    .navigationTitle("Export")
    .fileExporter(isPresented: $showingExporter, document: BackupDocument(url: exportURL), contentType: exportType, defaultFilename: exportURL?.deletingPathExtension().lastPathComponent) { result in
      if case .failure(let error) = result {
        logError("Error exporting report: \(error)")
      }
    }
  }

  // MARK: Private methods

  /// Builds the report data off-main, then renders the PDF.
  private func generatePDF() async throws {
    let data = try await ClinicianReportData.build(interval: range.interval)
    exportURL = try await MainActor.run {
      try ClinicianReportBuilder.makePDF(data: data, includeLog: includeLog, includeInsights: includeInsights)
    }
    exportType = .pdf
    showingExporter = true
  }

  /// Writes the CSV log.
  private func generateCSV() async throws {
    exportURL = try await ClinicianReportBuilder.makeCSV(interval: range.interval)
    exportType = .commaSeparatedText
    showingExporter = true
  }

}

struct ExportView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ExportView()
    }
    .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
    .environmentObject(Previewing.headacheManager)
  }
}
