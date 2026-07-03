//
//  PredictionViews.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct PredictionViews: View {

  /// The view's prediction.
  let prediction: RiskPrediction

  // MARK: Private properties

  // Preferences
  @AppStorage(Preferences.Lists.Keys.outlook) var showRiskView = Preferences.Lists.Defaults.shown

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

  /// What the outlook card should show.
  private var outlook: RiskOutlook {
    if let currentHeadache = currentHeadache {
      return .activeHeadache(severity: currentHeadache.severity, since: currentHeadache.startTime)
    }
    return .risk(prediction)
  }

  // MARK: View body

  var body: some View {
    if showRiskView && (currentHeadache != nil || prediction != .empty) {
      Section {
        NavigationLink {
          ModelInputView(input: prediction.input)
        } label: {
          OutlookView(outlook: outlook)
        }
      } header: {
        SectionTitleView(title: "Risk")
      } footer: {
        SectionFooterView(title: "Updated \(prediction.computedAt.formattedNonRelative()).")
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
