//
//  ListOptionsMenu.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct ListOptionsMenu: View {
  
  // Preferences
  @AppStorage(Preferences.Lists.Keys.type) private var showTypeView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.onset) private var showOnsetView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.duration) private var showDurationView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.progression) private var showProgressionView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.notes) private var showNotesView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.tags) private var showTagsView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.outlook) private var showOutlookView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.brief) private var showBriefView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.medications) private var showMedicationsView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.checkIn) private var showCheckInView = Preferences.Lists.Defaults.shown

  // MARK: View body

  var body: some View {
    Menu {
      Section {
        CheckmarkButton(title: "Type", checked: $showTypeView)
        CheckmarkButton(title: "Onset", checked: $showOnsetView)
        CheckmarkButton(title: "Duration", checked: $showDurationView)
        CheckmarkButton(title: "Progression", checked: $showProgressionView)
        CheckmarkButton(title: "Notes", checked: $showNotesView)
        CheckmarkButton(title: "Tags", checked: $showTagsView)
        CheckmarkButton(title: "Medications", checked: $showMedicationsView)
      }

      Section {
        CheckmarkButton(title: "Daily Check-In", checked: $showCheckInView)
      }

      Section {
        CheckmarkButton(title: "Risk", checked: $showOutlookView)
        CheckmarkButton(title: "Morning Brief", checked: $showBriefView)
      }
    } label: {
      Label("View Options", systemImage: "list.bullet.below.rectangle")
    }
  }
}

struct ListOptionsMenu_Previews: PreviewProvider {
  static var previews: some View {
    ListOptionsMenu()
  }
}
