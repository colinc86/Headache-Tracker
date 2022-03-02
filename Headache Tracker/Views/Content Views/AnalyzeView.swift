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
  
  enum FilterUnit: String, RawRepresentable {
    case day
    case week
    case month
    case year
    
    /// The range to use with the filter count picker.
    var filterCountRange: Range<Int> {
      switch self {
      case .day: return 1 ..< 8
      case .week: return 1 ..< 32
      case .month: return 1 ..< 13
      case .year: return 1 ..< 11
      }
    }
    
    /// The date before now with the number of `count` units of self
    /// before the current date.
    func dateBeforeNow(withCount count: Int) -> Date {
      var interval: TimeInterval = 0.0
      switch self {
      case .day:
        interval = TimeInterval(count) * 86400.0
      case .week:
        interval = TimeInterval(count) * 604800.0
      case .month:
        interval = TimeInterval(count) * 2678400.0
      case .year:
        interval = TimeInterval(count) * 31536000.0
      }
      return Date().addingTimeInterval(-interval)
    }
  }
  
  // MARK: Private properties
  
  /// The health integration setting.
  @AppStorage(AppSettings.filterCount) private var filterCount: Int = 1
  
  /// The health integration setting.
  @AppStorage(AppSettings.filterUnit) private var filterUnit: FilterUnit = .month
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The view's state identifier.
  @State private var viewIdentifier = UUID()
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      GraphList(filterUnit: filterUnit, earliestDate: filterUnit.dateBeforeNow(withCount: filterCount))
      .id(viewIdentifier)
      .navigationTitle("Analyze")
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          HStack {
            Text("Analyze the last")
            
            Picker("\(filterCount)", selection: $filterCount) {
              ForEach(filterUnit.filterCountRange, id: \.self) { i in
                Text("\(i)").tag(i)
              }
            }
            .padding([.leading, .trailing])
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterCount, perform: changedFilterCount)
            
            Picker("\(filterUnit.rawValue)\(filterCount == 1 ? "." : "s.")", selection: $filterUnit) {
              Text(FilterUnit.day.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.day)
              Text(FilterUnit.week.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.week)
              Text(FilterUnit.month.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.month)
              Text(FilterUnit.year.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.year)
            }
            .padding([.leading, .trailing])
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterUnit, perform: changedFilterUnit)
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
  
}

extension AnalyzeView {
  
  func changedFilterCount(_ newValue: Int) {
    withAnimation {
      viewIdentifier = UUID()
    }
  }
  
  /// Called when the filter unit changes.
  func changedFilterUnit(_ newValue: FilterUnit) {
    withAnimation {
      if filterCount < newValue.filterCountRange.lowerBound {
        filterCount = newValue.filterCountRange.lowerBound
      }
      else if filterCount > newValue.filterCountRange.upperBound - 1 {
        filterCount = newValue.filterCountRange.upperBound - 1
      }
      else {
        viewIdentifier = UUID()
      }
    }
  }
  
}

struct AnalyzeView_Previews: PreviewProvider {
  
  static var previews: some View {
    AnalyzeView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
  
}
