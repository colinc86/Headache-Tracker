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
  @AppStorage(Preferences.Lists.Keys.brief) var showBriefView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

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
          ModelInputView(input: prediction.input)
        } label: {
          OutlookView(outlook: outlook)
        }
      } header: {
        SectionTitleView(title: "Risk")
      } footer: {
        SectionFooterView(title: "Updated \(prediction.computedAt.formattedNonRelative()).")
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
