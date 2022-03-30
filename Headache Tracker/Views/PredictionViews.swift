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
  
  /// The view's list settings.
  @Environment(\.listSettings) private var listSettings
  
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
  
  // MARK: View body
  
  var body: some View {
    if listSettings.showOutlookView {
      Section {
        NavigationLink {
          ModelInputView(input: prediction.input)
        } label: {
          OutlookView(outlook: currentHeadache == nil ? prediction.holisticOutlook : .headache(severity: prediction.severityClassifierOutput.prediction, end: Date(timeIntervalSinceNow: prediction.durationRegressorOutput.prediction)))
        }
      } header: {
        SectionTitleView(title: "Predictions")
      } footer: {
        if !listSettings.showSeverityView, let lastPredictionDate = prediction.date {
          Text("Updated \(lastPredictionDate.formattedNonRelative()).")
        }
      }
    }
    
    if listSettings.showSeverityView {
      Section {
        SeveritySelectionView(currentSeverity: prediction.severityClassifierOutput.prediction, collapsed: true)
      } header: {
        if !listSettings.showOutlookView {
          SectionTitleView(title: "Predictions")
        }
      } footer: {
        if let lastPredictionDate = prediction.date {
          Text("Updated \(lastPredictionDate.formattedNonRelative()).")
        }
      }
    }
  }
}

struct PredictionViews_Previews: PreviewProvider {
  static var previews: some View {
    List {
      PredictionViews(prediction: Previewing.Prediction.prediction)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
    }
  }
}
