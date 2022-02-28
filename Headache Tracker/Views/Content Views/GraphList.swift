//
//  GraphList.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI
import Logger

struct GraphList: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The resolved headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest private var resolvedHeadaches: FetchedResults<Headache>
  
  /// The headache statistics to display.
  @State private var statistics: HeadacheStatistics?
  
  /// The earliest date to show in the view.
  private let earliestDate: Date
  
  var body: some View {
    List {
      if let statistics = statistics {
        Section {
          SubtitleCell(title: "Per Year", subtitle: String(format: "%0.1f", statistics.headachesPerYear))
          SubtitleCell(title: "Per Month", subtitle: String(format: "%0.1f", statistics.headachesPerMonth))
          SubtitleCell(title: "Per Week", subtitle: String(format: "%0.1f", statistics.headachesPerWeek))
        } header: {
          SectionTitleView(title: "Headaches")
        }
        
        Section {
          BarGraph(
            graphUnit: .severity,
            statistic: statistics.peaks,
            yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
            gradient: Gradient(colors: [.cyan.darker(by: 0.1), .cyan.lighter(by: 0.1)]),
            earliestDate: earliestDate,
            staticMax: 4)
            .frame(height: 100)
            .cell(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
          SubtitleCell(title: "Average", subtitle: statistics.peaks.meanDescription)
        } header: {
          SectionTitleView(title: "Severity")
        }
        
        Section {
          BarGraph(
            graphUnit: .severity,
            statistic: statistics.averages,
            yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
            gradient: Gradient(colors: [.cyan.darker(by: 0.1), .cyan.lighter(by: 0.1)]),
            earliestDate: earliestDate,
            staticMax: 4)
            .frame(height: 100)
            .cell(title: "Average Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
          SubtitleCell(title: "Average", subtitle: statistics.averages.meanDescription)
        }
        
        Section {
          BarGraph(
            graphUnit: .time,
            statistic: statistics.onsets,
            yAxis: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"],
            gradient: Gradient(colors: [.purple.darker(by: 0.1), .purple.lighter(by: 0.1)]),
            earliestDate: earliestDate,
            staticMax: 86400)
            .frame(height: 100)
            .cell(title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
          SubtitleCell(title: "Average", subtitle: statistics.onsets.meanDescription)
        } header: {
          SectionTitleView(title: "Onset")
        }
        
        Section {
          BarGraph(
            graphUnit: .duration,
            statistic: statistics.durations,
            yAxis: ["0m", Formatters.dateComponentsFormatter.string(from: statistics.durations.max ) ?? "-"],
            gradient: Gradient(colors: [.green.darker(by: 0.1), .green.lighter(by: 0.1)]),
            earliestDate: earliestDate)
            .frame(height: 100)
            .cell(title: "Duration", systemImage: "timer", foregroundColor: .green)
          SubtitleCell(title: "Average", subtitle: statistics.durations.meanDescription)
        } header: {
          SectionTitleView(title: "Duration")
        }
      }
    }
    .onAppear(perform: appeared)
  }
  
  // MARK: Initializers
  
  /// Intializes a graph list with an earliest date.
  ///
  /// - Parameter earliestDate: The earliest date to graph in the list.
  init(earliestDate: Date) {
    logDebug("Drawing graphs with earliest date \(earliestDate.formatted())")
    self.earliestDate = earliestDate
    let createdAtPredicate = NSPredicate(format: "createdAt >= %@", earliestDate as NSDate)
    let resolvedPredicate = NSPredicate(format: "resolved == %@", NSNumber(booleanLiteral: true))
    _resolvedHeadaches = FetchRequest<Headache>(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [createdAtPredicate, resolvedPredicate]))
  }
  
}

extension GraphList {
  
  /// Called when the view appears.
  func appeared() {
    let now = Date()
    statistics = HeadacheStatistics(headaches: resolvedHeadaches.sorted(by: { $0.startTime ?? now < $1.startTime ?? now }), earliestDate: earliestDate)
  }
  
}

struct GraphList_Previews: PreviewProvider {
  
  static var previews: some View {
    GraphList(earliestDate: Date())
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
  
}
