//
//  MedicationsCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// Shows a headache's medication entries with an edit affordance.
struct MedicationsCard: View {

  /// The headache whose medications to display.
  @ObservedObject var headache: Headache

  /// Called when the user wants to edit the medications.
  let editAction: () -> Void

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  // MARK: View body

  var body: some View {
    Card(title: "Medications", systemImage: "pills.fill", foregroundColor: colorTheme.teal) {
      Button("Edit", action: editAction)
        .font(.callout)
    } content: {
      if headache.medicationsArray.isEmpty {
        Text("Tap Edit to log a medication and whether it helped.")
          .font(.callout)
          .foregroundColor(.secondary)
      }
      else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(headache.medicationsArray, id: \.objectID) { entry in
            HStack {
              Image(systemName: entry.efficacy.systemImage)
                .foregroundColor(entry.efficacy == .unrated ? .secondary : colorTheme.teal)
                // Decorative — the efficacy is already spoken via its title.
                .accessibilityHidden(true)

              VStack(alignment: .leading) {
                Text(entry.name ?? "Medication")
                  .font(.callout)
                if let takenAt = entry.takenAt {
                  Text(Formatters.formatTimeWithDay(takenAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }

              Spacer()

              Text(entry.efficacy.title)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            // Read the row as one coherent phrase (name, time, efficacy)
            // instead of three separate VoiceOver stops.
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }

}

struct MedicationsCard_Previews: PreviewProvider {
  static var previews: some View {
    MedicationsCard(headache: Previewing.CoreData.resolvedHeadache, editAction: {})
      .previewLayout(.sizeThatFits)
  }
}
