//
//  NotesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct NotesView: View {
  let notes: String?
  var editButtonAction: (() -> Void)? = nil
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  var body: some View {
    TitleCaptionView(title: "Notes", systemImage: "note.text", foregroundColor: colorScheme.themeColor(for: .pink), editButtonAction: editButtonAction) {
      Text(notes ?? "Tap Edit to add notes.")
        .foregroundColor(notes == nil ? .secondary : .primary)
    }
  }
}

struct NotesView_Previews: PreviewProvider {
  static var previews: some View {
    NotesView(notes: """
This is a long string of test notes yeah let's see what happens
notes to see how the view will behave when
the user is allowed to enter whatever they
want.

🤕
""") {
      
    }
  }
}
