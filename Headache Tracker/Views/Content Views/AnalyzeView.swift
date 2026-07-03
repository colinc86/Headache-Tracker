//
//  AnalyzeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import Surge
import SwiftUI

struct AnalyzeView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  // Preferences
  @AppStorage(Preferences.Filters.Keys.count) private var filterCount = Preferences.Filters.Defaults.count
  @AppStorage(Preferences.Filters.Keys.unit) private var filterUnit = Preferences.Filters.Defaults.unit
  
  /// The view's state identifier.
  @State private var viewIdentifier = UUID()
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
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
            .onChange(of: filterCount) { _, newValue in changedFilterCount(newValue) }
            
            Picker("\(filterUnit.rawValue)\(filterCount == 1 ? "." : "s.")", selection: $filterUnit) {
              Text(FilterUnit.day.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.day)
              Text(FilterUnit.week.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.week)
              Text(FilterUnit.month.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.month)
              Text(FilterUnit.year.rawValue + (filterCount == 1 ? "." : "s.")).tag(FilterUnit.year)
            }
            .padding([.leading, .trailing])
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterUnit) { _, newValue in changedFilterUnit(newValue) }
          }
        }
      }
    }
  }
  
}

extension AnalyzeView {
  
  /// Changes the filter count.
  /// 
  /// - Parameter newValue: The new filter count value.
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
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
  
}
