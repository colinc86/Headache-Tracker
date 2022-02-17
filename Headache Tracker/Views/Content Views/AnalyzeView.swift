//
//  AnalyzeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI
import HealthKit

struct AnalyzeView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The resolveed headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: true)),
    animation: .default)
  private var resolvedHeadaches: FetchedResults<Headache>
  
  private var peakSeverities: [Double] {
    return resolvedHeadaches.map({ Double($0.severityRange.upperBound.orderingValue) })
  }
  
  private var peakSeverityAverage: Double {
    guard peakSeverities.count > 0 else { return 0.0 }
    return peakSeverities.reduce(0.0, +) / Double(peakSeverities.count)
  }
  
  private var peakSeverityAverageString: String {
    let roundedPeakSeverity = peakSeverityAverage.round(nearest: 0.5)
    let lowerBound = Int(floor(roundedPeakSeverity))
    let upperBound = Int(ceil(roundedPeakSeverity))
    guard let lowerSeverity = HKCategoryValueSeverity(orderingValue: lowerBound),
          let upperSeverity = HKCategoryValueSeverity(orderingValue: upperBound) else {
            return ""
          }
    return HealthKitManager.SeverityRange(lowerBound: lowerSeverity, upperBound: upperSeverity).description
  }
  
  private var averageSeverities: [Double] {
    return resolvedHeadaches.map({ Double($0.severityRange.average) })
  }
  
  private var averageSeverityAverage: Double {
    guard averageSeverities.count > 0 else { return 0.0 }
    return averageSeverities.reduce(0.0, +) / Double(averageSeverities.count)
  }
  
  private var averageSeverityAverageString: String {
    let roundedPeakSeverity = averageSeverityAverage.round(nearest: 0.5)
    let lowerBound = Int(floor(roundedPeakSeverity))
    let upperBound = Int(ceil(roundedPeakSeverity))
    guard let lowerSeverity = HKCategoryValueSeverity(orderingValue: lowerBound),
          let upperSeverity = HKCategoryValueSeverity(orderingValue: upperBound) else {
            return ""
          }
    return HealthKitManager.SeverityRange(lowerBound: lowerSeverity, upperBound: upperSeverity).description
  }
  
  private var onsets: [Double] {
    return resolvedHeadaches.map { headache in
      guard let startTime = headache.startTime else {
        return 0.0
      }
      return Calendar.current.timeIntervalSinceMidnight(startTime)
    }
  }
  
  private var onsetAverage: Double {
    guard onsets.count > 0 else { return 0.0 }
    return onsets.reduce(0.0, +) / Double(onsets.count)
  }
  
  private var onsetAverageDate: Date {
    return Calendar.current.startOfDay(for: Date()).addingTimeInterval(onsetAverage)
  }
  
  private var durations: [Double] {
    return resolvedHeadaches.map({ $0.duration })
  }
  
  private var durationAverage: Double {
    guard durations.count > 0 else { return 0.0 }
    return durations.reduce(0.0, +) / Double(durations.count)
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        Section {
          BarGraph(series: peakSeverities, average: peakSeverityAverage, gradient: Gradient(colors: [.cyan, .teal]))
            .frame(height: 100)
            .cell(title: "Peak Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
          SubtitleCell(title: "Average", subtitle: peakSeverityAverageString)
        } header: {
          SectionTitleView(title: "Severity")
        }
        
        Section {
          BarGraph(series: averageSeverities, average: averageSeverityAverage, gradient: Gradient(colors: [.cyan, .teal]))
            .frame(height: 100)
            .cell(title: "Average Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
          SubtitleCell(title: "Average", subtitle: averageSeverityAverageString)
        }
        
        Section {
          BarGraph(series: onsets, average: onsetAverage, gradient: Gradient(colors: [.purple, .indigo]))
            .frame(height: 100)
            .cell(title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
          SubtitleCell(title: "Average", subtitle: onsetAverageDate.formatted(date: .omitted, time: .standard))
        } header: {
          SectionTitleView(title: "Onset")
        }
        
        Section {
          BarGraph(series: durations, average: durationAverage, gradient: Gradient(colors: [.green, .mint]))
            .frame(height: 100)
            .cell(title: "Duration", systemImage: "timer", foregroundColor: .green)
          if let formattedAverage = Formatters.dateComponentsFormatter.string(from: durationAverage) {
            SubtitleCell(title: "Average", subtitle: formattedAverage)
          }
        } header: {
          SectionTitleView(title: "Duration")
        }
      }
      .navigationTitle("Analyze")
    }
  }
  
}

struct AnalyzeView_Previews: PreviewProvider {
  static var previews: some View {
    AnalyzeView()
  }
}
