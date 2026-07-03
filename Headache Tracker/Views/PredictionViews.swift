//
//  PredictionViews.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct PredictionViews: View {
  
  /// The view's prediction.
  let prediction: PredictionOutput
  
  // MARK: Private properties
  
  // Preferences
  @AppStorage(Preferences.Lists.Keys.outlook) var showOutlookView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.severity) var showSeverityView = Preferences.Lists.Defaults.shown
  
  /// The headaches fetch request.
  /// Should only return one headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The current (unresolved) headache.
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  private var needsSeverityView: Bool {
    switch prediction.holisticOutlook {
    case .noHeadache:
      return false
    case .possibleHeadache(_):
      return false
    case .headache(let severity, _):
      return severity != .notPresent
    }
  }
  
  // MARK: View body
  
  var body: some View {
    if showOutlookView {
      Section {
        NavigationLink {
          ModelInputView(input: prediction.input)
        } label: {
          OutlookView(outlook: currentHeadache == nil ? prediction.holisticOutlook : .headache(severity: prediction.severityClassifierOutput.prediction, end: Date(timeIntervalSinceNow: prediction.durationRegressorOutput.prediction)))
        }
      } header: {
        SectionTitleView(title: "Predictions")
      } footer: {
        if !showSeverityView  {
          SectionFooterView(title: "Updated \(prediction.date.formattedNonRelative()).")
        }
      }
    }
    
    if showSeverityView && needsSeverityView {
      Section {
        SeveritySelectionView(currentSeverity: prediction.severityClassifierOutput.prediction, collapsed: true)
      } header: {
        if !showOutlookView {
          SectionTitleView(title: "Predictions")
        }
      } footer: {
        SectionFooterView(title: "Updated \(prediction.date.formattedNonRelative()).")
      }
    }
  }
}

struct PredictionViews_Previews: PreviewProvider {
  static var previews: some View {
    ScrollView {
      PredictionViews(prediction: Previewing.Prediction.prediction)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
    }
    .background(Color(UIColor.systemGroupedBackground))
  }
}
