//
//  EditNotesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct EditNotesView: View {
  
  @State var notes: String
  @State var identifier: UUID
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  @Environment(\.presentationMode) private var presentationMode
  @State private var saving: Bool = false
  
  var body: some View {
    NavigationView {
      ZStack(alignment: .topLeading) {
        TextEditor(text: $notes)
        
        if notes.isEmpty {
          Text("Tap to add notes.")
            .foregroundColor(.secondary)
            .padding(.leading, 5)
            .padding(.top, 8)
        }
      }
      .padding()
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
  
  private func cancel() {
    dismiss()
  }
  
  private func save() async throws {
    withAnimation {
      saving = true
    }
    
    try await headacheManager.updateHeadacheNotes(notes.isEmpty ? nil : notes, identifier: identifier)
    
    dismiss()
  }
  
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
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
