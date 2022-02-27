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
  
  enum FilterUnit: String {
    case day
    case week
    case month
    case year
    
    var filterCountRange: Range<Int> {
      switch self {
      case .day: return 1 ..< 8
      case .week: return 1 ..< 32
      case .month: return 1 ..< 13
      case .year: return 1 ..< 11
      }
    }
  }
  
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
  
  @State private var filterCount: Int = 1
  @State private var filterUnit: FilterUnit = .day
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        if let statistics = statistics {
          Section {
            BarGraph(
              statistic: statistics.peaks,
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
              statistic: statistics.averages,
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
              statistic: statistics.onsets,
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
              statistic: statistics.durations,
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
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          HStack {
            Text("Analyze the last")
            
            Picker("\(filterCount)", selection: $filterCount) {
              ForEach(filterUnit.filterCountRange) { i in
                Text("\(i)").tag(i)
              }
            }
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            
            Picker("\(filterUnit.rawValue)\(filterCount == 1 ? "" : "s")", selection: $filterUnit) {
              Text(FilterUnit.day.rawValue).tag(FilterUnit.day)
              Text(FilterUnit.week.rawValue).tag(FilterUnit.week)
              Text(FilterUnit.month.rawValue).tag(FilterUnit.month)
              Text(FilterUnit.year.rawValue).tag(FilterUnit.year)
            }
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterUnit, perform: changedFilterUnit)
            
            
//            Picker("\(filterUnit.rawValue)\(filterCount == 1 ? "" : "s")", selection: $filterUnit) {
//              Text(FilterUnit.day.rawValue).tag(FilterUnit.day)
//              Text(FilterUnit.week.rawValue).tag(FilterUnit.week)
//              Text(FilterUnit.month.rawValue).tag(FilterUnit.month)
//              Text(FilterUnit.year.rawValue).tag(FilterUnit.year)
//            }
//            .overlay(
//              RoundedRectangle(cornerRadius: 8)
//                .fill(Color.secondary.opacity(0.25))
//            )
            
            
            Text(".")
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .onAppear(perform: appeared)
  }
  
}

extension AnalyzeView {
  
  /// Called when the view appears.
  func appeared() {
    let now = Date()
    statistics = HeadacheStatistics(headaches: resolvedHeadaches.sorted(by: { $0.startTime ?? now < $1.startTime ?? now }))
  }
  
  /// Called when the filter unit changes.
  func changedFilterUnit(_ newValue: FilterUnit) {
    if filterCount < newValue.filterCountRange.lowerBound {
      filterCount = newValue.filterCountRange.lowerBound
    }
    else if filterCount > newValue.filterCountRange.upperBound - 1 {
      filterCount = newValue.filterCountRange.upperBound - 1
    }
  }
  
}

struct AnalyzeView_Previews: PreviewProvider {
  static var previews: some View {
    AnalyzeView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
}
