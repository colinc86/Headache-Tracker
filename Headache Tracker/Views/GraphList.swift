//
//  GraphList.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI

struct GraphList: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// The resolved headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest private var resolvedHeadaches: FetchedResults<Headache>

  /// The headache statistics to display.
  @State private var statistics: HeadacheStatistics?

  /// The top correlation insights.
  @State private var topInsights = [TriggerInsight]()
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  /// The analyze view's filter unit.
  private let filterUnit: FilterUnit
  
  /// The earliest date to show in the view.
  private let earliestDate: Date
  
  var body: some View {
    List {
      // Possible triggers
      Section {
        if topInsights.isEmpty {
          NavigationLink {
            InsightsView()
          } label: {
            Label("Possible Triggers", systemImage: "sparkle.magnifyingglass")
          }
        }
        else {
          ForEach(topInsights.prefix(3)) { insight in
            NavigationLink {
              TriggerDetailView(insight: insight)
            } label: {
              TriggerInsightCell(insight: insight)
            }
          }

          NavigationLink {
            InsightsView()
          } label: {
            Text("All Insights")
              .foregroundColor(colorTheme.baseColor)
          }
        }
      } header: {
        SectionTitleView(title: "Insights")
      }

      if let statistics = statistics {
        if filterUnit == .year || filterUnit == .month || filterUnit == .week {
          Section {
            if filterUnit == .year {
              SubtitleCell(
                title: "Headaches Per Year",
                subtitle: String(format: "%0.1f", statistics.headachesPerYear),
                systemImage: statistics.headachesPerYearTrend.systemImage,
                imageForegroundColor: statistics.headachesPerYearTrend.foregroundColor(for: colorTheme))
            }
            else if filterUnit == .month {
              SubtitleCell(
                title: "Headaches Per Month",
                subtitle: String(format: "%0.1f", statistics.headachesPerMonth),
                systemImage: statistics.headachesPerMonthTrend.systemImage,
                imageForegroundColor: statistics.headachesPerMonthTrend.foregroundColor(for: colorTheme))
            }
            else {
              SubtitleCell(
                title: "Headaches Per Week",
                subtitle: String(format: "%0.1f", statistics.headachesPerWeek),
                systemImage: statistics.headachesPerWeekTrend.systemImage,
                imageForegroundColor: statistics.headachesPerWeekTrend.foregroundColor(for: colorTheme))
            }
          } header: {
            SectionTitleView(title: "Headaches")
          }
        }
        
        Section {
          Card(title: "Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
            BlockGraph(series: statistics.severityRanges, earliestDate: earliestDate)
          }
            .cardListRow()
        } header: {
          SectionTitleView(title: "Severity")
        }
        
        Section {
          Card(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
            BarGraph(
              graphUnit: .severity,
              statistic: statistics.peaks,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [colorTheme.cyan.darker(by: 0.1), colorTheme.cyan.lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 4)
              .frame(height: 100)
          }
            .cardListRow()
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.peaks.meanDescription,
            systemImage: statistics.peaks.meanTrend.systemImage,
            imageForegroundColor: statistics.peaks.meanTrend.foregroundColor(for: colorTheme))
        }
        
        Section {
          Card(title: "Average Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
            BarGraph(
              graphUnit: .severity,
              statistic: statistics.averages,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [colorTheme.cyan.darker(by: 0.1), colorTheme.cyan.lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 4)
              .frame(height: 100)
          }
            .cardListRow()
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.averages.meanDescription,
            systemImage: statistics.averages.meanTrend.systemImage,
            imageForegroundColor: statistics.averages.meanTrend.foregroundColor(for: colorTheme))
        }
        
        Section {
          Card(title: "Onset", systemImage: "clock.fill", foregroundColor: colorTheme.purple) {
            BarGraph(
              graphUnit: .time,
              statistic: statistics.onsets,
              yAxis: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"],
              gradient: Gradient(colors: [colorTheme.purple.darker(by: 0.1), colorTheme.purple.lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 86400)
              .frame(height: 100)
          }
            .cardListRow()
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.onsets.meanDescription,
            systemImage: statistics.onsets.meanTrend.systemImage,
            imageForegroundColor: statistics.onsets.meanTrend.foregroundColor(for: colorTheme))
        } header: {
          SectionTitleView(title: "Onset")
        }
        
        Section {
          Card(title: "Duration", systemImage: "timer", foregroundColor: colorTheme.green) {
            BarGraph(
              graphUnit: .duration,
              statistic: statistics.durations,
              yAxis: ["0m", Formatters.formatInterval(statistics.durations.max)],
              gradient: Gradient(colors: [colorTheme.green.darker(by: 0.1), colorTheme.green.lighter(by: 0.1)]),
              earliestDate: earliestDate)
              .frame(height: 100)
          }
            .cardListRow()
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.durations.meanDescription,
            systemImage: statistics.durations.meanTrend.systemImage,
            imageForegroundColor: statistics.durations.meanTrend.foregroundColor(for: colorTheme))
          SubtitleCell(
            title: "Min",
            subtitle: statistics.durations.minDescription,
            systemImage: statistics.durations.minTrend.systemImage,
            imageForegroundColor: statistics.durations.minTrend.foregroundColor(for: colorTheme))
          SubtitleCell(
            title: "Max",
            subtitle: statistics.durations.maxDescription,
            systemImage: statistics.durations.maxTrend.systemImage,
            imageForegroundColor: statistics.durations.maxTrend.foregroundColor(for: colorTheme))
        } header: {
          SectionTitleView(title: "Duration")
        }
      }
    }
    .onAppear(perform: appeared)
    .task {
      await loadInsights()
    }
  }
  
  // MARK: Initializers
  
  /// Initilized a graph list with an earliest date.
  ///
  /// - Parameters:
  ///   - filterUnit: The analyze view's filter unit.
  ///   - earliestDate: The earilest date to garph in the list.
  init(filterUnit: FilterUnit, earliestDate: Date) {
    self.filterUnit = filterUnit
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

  /// Loads the top correlation insights.
  func loadInsights() async {
    do {
      topInsights = try await headacheManager.insights().insights
    }
    catch {
      logError("Error loading insights: \(error)")
    }
  }

}

struct GraphList_Previews: PreviewProvider {
  
  static var previews: some View {
    GraphList(filterUnit: .day, earliestDate: Date(timeIntervalSinceNow: -600))
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
  
}
