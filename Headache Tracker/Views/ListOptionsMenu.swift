//
//  ListOptionsMenu.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct ListOptionsMenu: View {
  
  /// Whether the type view should be shown.
  @AppStorage(AppSettings.ListOptions.type) private var type = true
  
  /// Whether the onset view should be shown.
  @AppStorage(AppSettings.ListOptions.onset) private var onset = true
  
  /// Whether the duration view should be shown.
  @AppStorage(AppSettings.ListOptions.duration) private var duration = true
  
  /// Whether the progression view should be shown.
  @AppStorage(AppSettings.ListOptions.progression) private var progression = true
  
  /// Whether the notes view should be shown.
  @AppStorage(AppSettings.ListOptions.notes) private var notes = true
  
  /// Whether the tags view should be shown.
  @AppStorage(AppSettings.ListOptions.tags) private var tags = true
  
  /// Whether the outlook view should be shown.
  @AppStorage(AppSettings.ListOptions.outlook) private var outlook = true
  
  /// Whether the severity view should be shown.
  @AppStorage(AppSettings.ListOptions.severity) private var severity = true
  
  var body: some View {
    Menu {
      Section {
        CheckmarkButton(title: "Type", checked: $type)
        CheckmarkButton(title: "Onset", checked: $onset)
        CheckmarkButton(title: "Duration", checked: $duration)
        CheckmarkButton(title: "Progression", checked: $progression)
        CheckmarkButton(title: "Notes", checked: $notes)
        CheckmarkButton(title: "Tags", checked: $tags)
      }
      
      Section {
        CheckmarkButton(title: "Outlook", checked: $outlook)
        CheckmarkButton(title: "Severity", checked: $severity)
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
