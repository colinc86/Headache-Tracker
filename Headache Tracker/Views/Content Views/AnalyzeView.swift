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
  
  /// The view's list settings.
  @Environment(\.filterSettings) private var filterSettings
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The view's state identifier.
  @State private var viewIdentifier = UUID()
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      GraphList(filterUnit: filterSettings.unit, earliestDate: filterSettings.unit.dateBeforeNow(withCount: filterSettings.count))
      .id(viewIdentifier)
      .navigationTitle("Analyze")
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          HStack {
            Text("Analyze the last")
            
            Picker("\(filterSettings.count)", selection: filterSettings.$count) {
              ForEach(filterSettings.unit.filterCountRange, id: \.self) { i in
                Text("\(i)").tag(i)
              }
            }
            .padding([.leading, .trailing])
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterSettings.count, perform: changedFilterCount)
            
            Picker("\(filterSettings.unit.rawValue)\(filterSettings.count == 1 ? "." : "s.")", selection: filterSettings.$unit) {
              Text(FilterUnit.day.rawValue + (filterSettings.count == 1 ? "." : "s.")).tag(FilterUnit.day)
              Text(FilterUnit.week.rawValue + (filterSettings.count == 1 ? "." : "s.")).tag(FilterUnit.week)
              Text(FilterUnit.month.rawValue + (filterSettings.count == 1 ? "." : "s.")).tag(FilterUnit.month)
              Text(FilterUnit.year.rawValue + (filterSettings.count == 1 ? "." : "s.")).tag(FilterUnit.year)
            }
            .padding([.leading, .trailing])
            .background(RoundedRectangle(cornerRadius: 8)
                          .fill(Color.secondary.opacity(0.25)))
            .onChange(of: filterSettings.unit, perform: changedFilterUnit)
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
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
      if filterSettings.count < newValue.filterCountRange.lowerBound {
        filterSettings.count = newValue.filterCountRange.lowerBound
      }
      else if filterSettings.count > newValue.filterCountRange.upperBound - 1 {
        filterSettings.count = newValue.filterCountRange.upperBound - 1
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
