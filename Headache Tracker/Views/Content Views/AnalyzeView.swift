//
//  AnalyzeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Surge
import SwiftUI
import HealthKit

struct AnalyzeView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The resolved headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: true)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: true)),
    animation: .default)
  private var resolvedHeadaches: FetchedResults<Headache>
  
  /// The headache statistics to display.
  @State private var statistics: HeadacheStatistics?
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        if let statistics = statistics {
          Section {
            BarGraph(
              series: statistics.peaks.signal,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [.cyan, .teal]),
              staticCount: 28,
              staticMax: 4)
              .frame(height: 100)
              .cell(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
            SubtitleCell(title: "Average", subtitle: statistics.peaks.meanDescription)
          } header: {
            SectionTitleView(title: "Severity")
          }
          
          Section {
            BarGraph(
              series: statistics.averages.signal,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [.cyan, .teal]),
              staticCount: 28,
              staticMax: 4)
              .frame(height: 100)
              .cell(title: "Average Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
            SubtitleCell(title: "Average", subtitle: statistics.averages.meanDescription)
          }
          
          Section {
            BarGraph(
              series: statistics.onsets.signal,
              yAxis: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"],
              gradient: Gradient(colors: [.purple, .indigo]),
              staticCount: 28,
              staticMax: 86400)
              .frame(height: 100)
              .cell(title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
            SubtitleCell(title: "Average", subtitle: statistics.onsets.meanDescription)
          } header: {
            SectionTitleView(title: "Onset")
          }
          
          Section {
            BarGraph(
              series: statistics.durations.signal,
              yAxis: ["0m", Formatters.dateComponentsFormatter.string(from: statistics.durations.max ) ?? "-"],
              gradient: Gradient(colors: [.green, .mint]),
              staticCount: 28)
              .frame(height: 100)
              .cell(title: "Duration", systemImage: "timer", foregroundColor: .green)
            SubtitleCell(title: "Average", subtitle: statistics.durations.meanDescription)
          } header: {
            SectionTitleView(title: "Duration")
          }
        }
      }
      .navigationTitle("Analyze")
    }
    .onAppear(perform: appeared)
  }
  
}

extension AnalyzeView {
  
  /// Called when the view appears.
  func appeared() {
    let now = Date()
    statistics = HeadacheStatistics(headaches: resolvedHeadaches.sorted(by: { $0.startTime ?? now < $1.startTime ?? now }))
  }
  
}

struct AnalyzeView_Previews: PreviewProvider {
  static var previews: some View {
    AnalyzeView()
  }
}
