//
//  PredictionViews.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct PredictionViews: View {
  
  /// The view's prediction.
  let prediction: Predictor.Prediction
  
  // MARK: Private properties
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
  
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
    let dailyOutlook = OutlookView(outlook: prediction.holisticOutlook)
    let durationPrediction = DurationPredictionView(duration: prediction.durationRegressorOutput.prediction)
    let severityPrediction = SeveritySelectionView(currentSeverity: prediction.severityClassifierOutput.prediction, collapsed: true)
    
    if debugShowAllViews {
      Section {
        dailyOutlook
      } header: {
        SectionTitleView(title: "Predictions")
      }
      
      Section {
        durationPrediction
      }
      
      Section {
        severityPrediction
      } footer: {
        if let lastPredictionDate = prediction.date {
          Text("Updated \(lastPredictionDate.formattedNonRelative()).")
        }
      }
    }
    else if currentHeadache == nil {
      Section {
        dailyOutlook
      } header: {
        SectionTitleView(title: "Predictions")
      }
      
      Section {
        severityPrediction
      } footer: {
        if let lastPredictionDate = prediction.date {
          Text("Updated at \(lastPredictionDate.formattedNonRelative()).")
        }
      }
    }
    else {
      Section {
        durationPrediction
      } header: {
        SectionTitleView(title: "Predictions")
      }
      
      Section {
        severityPrediction
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
