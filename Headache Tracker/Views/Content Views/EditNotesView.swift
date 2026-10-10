//
//  EditNotesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct EditNotesView: View {
  
  /// The notes to edit.
  @State var notes: String
  
  /// The identifier of the headache to edit.
  @State var identifier: UUID
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.dismiss) private var dismiss
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// Whether the view is being saved.
  @State private var saving: Bool = false

  /// Focuses the editor so the keyboard is ready the moment the sheet opens.
  @FocusState private var editorFocused: Bool

  var body: some View {
    NavigationStack {
      ZStack(alignment: .topLeading) {
        TextEditor(text: $notes)
          .focused($editorFocused)

        if notes.isEmpty {
          Text("Tap to add notes.")
            .foregroundColor(.secondary)
            .padding(.leading, 5)
            .padding(.top, 8)
            .allowsHitTesting(false)
        }
      }
      .padding()
      .onAppear { editorFocused = true }
      .navigationTitle("Notes")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel, action: cancel)
            .disabled(saving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
          AsyncButton("Save", mode: .replacingContent, action: save)
        }
      }
    }
  }
  
}

// MARK: Private methods

extension EditNotesView {
  
  /// The cancel action.
  private func cancel() {
    dismiss()
  }
  
  /// Saves the headache.
  ///
  /// `@MainActor` so the `saving` state and `dismiss()` run on the main thread
  /// (`updateHeadacheNotes` does its work off-main on a background context).
  @MainActor private func save() async throws {
    withAnimation {
      saving = true
    }
    // Reset on every exit. A failed save throws to the AsyncButton's alert
    // instead of dismissing, so without this the Cancel button would stay
    // stuck disabled and trap the user in the editor.
    defer { saving = false }

    try await headacheManager.updateHeadacheNotes(notes.isEmpty ? nil : notes, identifier: identifier)

    dismiss()
  }
  
}

struct EditNotesView_Previews: PreviewProvider {
  static var previews: some View {
    EditNotesView(notes: Previewing.CoreData.resolvedHeadache.notes ?? "", identifier: Previewing.CoreData.resolvedHeadache.identifier ?? UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
