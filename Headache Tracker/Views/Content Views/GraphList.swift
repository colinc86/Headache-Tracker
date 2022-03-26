//
//  GraphList.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/27/22.
//

import SwiftUI

struct GraphList: View {
  
  // MARK: Private properties
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  /// The resolved headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest private var resolvedHeadaches: FetchedResults<Headache>
  
  /// The headache statistics to display.
  @State private var statistics: HeadacheStatistics?
  
  /// The analyze view's filter unit.
  private let filterUnit: AnalyzeView.FilterUnit
  
  /// The earliest date to show in the view.
  private let earliestDate: Date
  
  var body: some View {
    List {
      if let statistics = statistics {
        if filterUnit == .year || filterUnit == .month || filterUnit == .week {
          Section {
            if filterUnit == .year {
              SubtitleCell(
                title: "Heaches Per Year",
                subtitle: String(format: "%0.1f", statistics.headachesPerYear),
                systemImage: statistics.headachesPerYearTrend.systemImage,
                imageForegroundColor: colorScheme.themeColor(for: statistics.headachesPerYearTrend.foregroundColor))
            }
            else if filterUnit == .month {
              SubtitleCell(
                title: "Heaches Per Month",
                subtitle: String(format: "%0.1f", statistics.headachesPerMonth),
                systemImage: statistics.headachesPerMonthTrend.systemImage,
                imageForegroundColor: colorScheme.themeColor(for: statistics.headachesPerMonthTrend.foregroundColor))
            }
            else {
              SubtitleCell(
                title: "Heaches Per Week",
                subtitle: String(format: "%0.1f", statistics.headachesPerWeek),
                systemImage: statistics.headachesPerWeekTrend.systemImage,
                imageForegroundColor: colorScheme.themeColor(for: statistics.headachesPerWeekTrend.foregroundColor))
            }
          } header: {
            SectionTitleView(title: "Headaches")
          }
        }
        
        Section {
          TitleCaptionView(title: "Severity", systemImage: "dial.max.fill", foregroundColor: colorScheme.themeColor(for: .cyan)) {
            BlockGraph(series: statistics.severityRanges, earliestDate: earliestDate)
          }
        } header: {
          SectionTitleView(title: "Severity")
        }
        
        Section {
          TitleCaptionView(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: colorScheme.themeColor(for: .cyan)) {
            BarGraph(
              graphUnit: .severity,
              statistic: statistics.peaks,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [colorScheme.themeColor(for: .cyan).darker(by: 0.1), colorScheme.themeColor(for: .cyan).lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 4)
              .frame(height: 100)
          }
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.peaks.meanDescription,
            systemImage: statistics.peaks.meanTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.peaks.meanTrend.foregroundColor))
        }
        
        Section {
          TitleCaptionView(title: "Average Severity", systemImage: "dial.max.fill", foregroundColor: colorScheme.themeColor(for: .cyan)) {
            BarGraph(
              graphUnit: .severity,
              statistic: statistics.averages,
              yAxis: ["Not Present", "Present", "Mild", "Moderate", "Severe"],
              gradient: Gradient(colors: [colorScheme.themeColor(for: .cyan).darker(by: 0.1), colorScheme.themeColor(for: .cyan).lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 4)
              .frame(height: 100)
          }
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.averages.meanDescription,
            systemImage: statistics.averages.meanTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.averages.meanTrend.foregroundColor))
        }
        
        Section {
          TitleCaptionView(title: "Onset", systemImage: "clock.fill", foregroundColor: colorScheme.themeColor(for: .purple)) {
            BarGraph(
              graphUnit: .time,
              statistic: statistics.onsets,
              yAxis: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"],
              gradient: Gradient(colors: [colorScheme.themeColor(for: .purple).darker(by: 0.1), colorScheme.themeColor(for: .purple).lighter(by: 0.1)]),
              earliestDate: earliestDate,
              staticMax: 86400)
              .frame(height: 100)
          }
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.onsets.meanDescription,
            systemImage: statistics.onsets.meanTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.onsets.meanTrend.foregroundColor))
        } header: {
          SectionTitleView(title: "Onset")
        }
        
        Section {
          TitleCaptionView(title: "Duration", systemImage: "timer", foregroundColor: colorScheme.themeColor(for: .green)) {
            BarGraph(
              graphUnit: .duration,
              statistic: statistics.durations,
              yAxis: ["0m", Formatters.formatInterval(statistics.durations.max)],
              gradient: Gradient(colors: [colorScheme.themeColor(for: .green).darker(by: 0.1), colorScheme.themeColor(for: .green).lighter(by: 0.1)]),
              earliestDate: earliestDate)
              .frame(height: 100)
          }
          
          SubtitleCell(
            title: "Mean",
            subtitle: statistics.durations.meanDescription,
            systemImage: statistics.durations.meanTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.durations.meanTrend.foregroundColor))
          SubtitleCell(
            title: "Min",
            subtitle: statistics.durations.minDescription,
            systemImage: statistics.durations.minTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.durations.minTrend.foregroundColor))
          SubtitleCell(
            title: "Max",
            subtitle: statistics.durations.maxDescription,
            systemImage: statistics.durations.maxTrend.systemImage,
            imageForegroundColor: colorScheme.themeColor(for: statistics.durations.maxTrend.foregroundColor))
        } header: {
          SectionTitleView(title: "Duration")
        }
      }
    }
    .onAppear(perform: appeared)
  }
  
  // MARK: Initializers
  
  /// Initilized a graph list with an earliest date.
  ///
  /// - Parameters:
  ///   - filterUnit: The analyze view's filter unit.
  ///   - earliestDate: The earilest date to garph in the list.
  init(filterUnit: AnalyzeView.FilterUnit, earliestDate: Date) {
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
