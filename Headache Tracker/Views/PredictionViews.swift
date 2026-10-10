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

  /// The headline accuracy shown beside the confidence grade.
  var accuracy: ForecastAccuracy? = nil

  // MARK: Private properties

  // Preferences
  @AppStorage(Preferences.Lists.Keys.outlook) var showRiskView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.brief) var showBriefView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The predictor, for the training provenance behind the footer.
  @EnvironmentObject private var predictor: Predictor

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

  /// The morning brief for the reasons card (nil during a headache or when
  /// there's nothing to explain).
  private var brief: RiskBrief? {
    guard currentHeadache == nil else {
      return nil
    }
    return RiskBriefBuilder.makeBrief(
      risk: prediction,
      todayValues: prediction.input.correlationValues(),
      report: InsightsStore.shared.load())
  }

  // MARK: View body

  var body: some View {
    if showRiskView && (currentHeadache != nil || prediction != .empty) {
      Section {
        NavigationLink {
          ModelInputView(prediction: prediction)
        } label: {
          OutlookHeroView(outlook: outlook, accuracy: accuracy)
        }
        .cardListRow()
      } footer: {
        // Only a forecast has a meaningful "updated" time. During a headache the
        // hero shows the live headache state, and an empty prediction's sentinel
        // date (Date(timeIntervalSince1970: 0)) would otherwise surface as
        // "Updated Jan 1, 1970" — e.g. for a new user whose first log precedes
        // any trained model. When forecasting, the body guard guarantees a
        // non-empty prediction, so `computedAt` is always real here.
        if currentHeadache == nil {
          SectionFooterView(title: ([predictor.metrics?.provenanceSummary, prediction.shortCaption, "Updated \(prediction.computedAt.formattedNonRelative())"].compactMap({ $0 })).joined(separator: " · ") + ".")
        }
      }

      // Why: the strongest baseline deviations behind today's risk
      if showBriefView, let brief = brief, !brief.reasons.isEmpty {
        Section {
          Card(title: "Why", systemImage: "questionmark.circle.fill", foregroundColor: colorTheme.indigo) {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(brief.reasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: 6) {
                  Image(systemName: "arrow.up.right.circle")
                    .font(.caption)
                    .padding(.top, 3)
                  Text(reason)
                    .font(.callout)
                }
              }
            }
          }
          .cardListRow()
        } footer: {
          SectionFooterView(title: "Today vs. your 14-day baseline, for signals that correlate with your headaches.")
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
