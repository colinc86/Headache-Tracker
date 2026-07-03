//
//  DailyCheckInCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// Shows today's logged exposures with an edit affordance.
struct DailyCheckInCard: View {

  /// Today's logged exposure kind raw values.
  let kinds: [String]

  /// Called when the user wants to edit the check-in.
  let editAction: () -> Void

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  // MARK: View body

  var body: some View {
    Card(title: "Daily Check-In", systemImage: "checklist", foregroundColor: colorTheme.orange) {
      Button("Edit", action: editAction)
        .font(.callout)
    } content: {
      if kinds.isEmpty {
        Text("What did today look like? Log caffeine, alcohol, stress, and more to sharpen your insights.")
          .font(.callout)
          .foregroundColor(.secondary)
      }
      else {
        FlexibleView(data: kinds, spacing: Tokens.Spacing.sm, alignment: .leading) { kind in
          Chip(
            title: ExposureKind(rawValue: kind)?.title ?? kind.capitalized,
            systemImage: ExposureKind(rawValue: kind)?.systemImage ?? "tag.fill",
            style: .readonly)
        }
      }
    }
  }

}

struct DailyCheckInCard_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      DailyCheckInCard(kinds: ["caffeine", "stress", "skipped-meal"], editAction: {})
      DailyCheckInCard(kinds: [], editAction: {})
    }
    .previewLayout(.sizeThatFits)
  }
}
