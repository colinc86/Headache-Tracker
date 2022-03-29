//
//  NotesCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct NotesCard: View {
  
  /// The notes to display.
  let notes: String
  
  /// The action to call when the edit button is tapped.
  let editAction: () -> Void
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @Environment(\.colorTheme) private var colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Notes",
      systemImage: "note.text",
      foregroundColor: colorTheme.pink
    ) {
      Button("Edit", action: editAction)
    } content: {
      Text(notes.isEmpty ? "Tap Edit to add notes." : notes)
        .foregroundColor(notes.isEmpty ? .secondary : .primary)
    }
  }
}

struct NotesCard_Previews: PreviewProvider {
  static var previews: some View {
    NotesCard(notes:
"""
This is a long string of test notes yeah let's see what happens
notes to see how the view will behave when
the user is allowed to enter whatever they
want.

🤕
"""
    ) {
      // Edit action
    }
    .previewLayout(.fixed(width: 428, height: 70))
  }
}
