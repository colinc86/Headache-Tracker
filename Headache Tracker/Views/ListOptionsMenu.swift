//
//  ListOptionsMenu.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct ListOptionsMenu: View {
  
  /// The view's list settings.
  @Environment(\.listSettings) private var listSettings
  
  // MARK: View body
  
  var body: some View {
    Menu {
      Section {
        CheckmarkButton(title: "Type", checked: listSettings.$showTypeView)
        CheckmarkButton(title: "Onset", checked: listSettings.$showOnsetView)
        CheckmarkButton(title: "Duration", checked: listSettings.$showDurationView)
        CheckmarkButton(title: "Progression", checked: listSettings.$showProgressionView)
        CheckmarkButton(title: "Notes", checked: listSettings.$showNotesView)
        CheckmarkButton(title: "Tags", checked: listSettings.$showTagsView)
      }
      
      Section {
        CheckmarkButton(title: "Outlook", checked: listSettings.$showOutlookView)
        CheckmarkButton(title: "Severity", checked: listSettings.$showSeverityView)
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
