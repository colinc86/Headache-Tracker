//
//  AddHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/14/22.
//

import SwiftUI

struct AddHeadacheView: View {
  
  // MARK: Private properties
  
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  private let now: Date
  @State private var severity: Headache.Severity? = nil
  @State private var onset = Date()
  @State private var resolved = false
  @State private var end = Date()
  @State private var isSaving = false
  var valid: Bool {
    return severity != nil && onset < now
  }
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: severity, action: changeSeverity)
      } header: {
        SectionTitleView(title: "How severe was the headache?")
      } footer: {
        Text("You can modify this and add more values later.")
      }
      
      Section {
        EditableDateTimeCardView(onset: $onset, title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
      } header: {
        SectionTitleView(title: "When did it start?")
      }
      
      Section {
        Toggle("Resolved", isOn: $resolved)
          .tint(.accentColor)
      } header: {
        SectionTitleView(title: "Has it resolved?")
      }
      
      if resolved {
        Section {
          EditableDateTimeCardView(onset: $end, title: "End", systemImage: "clock.fill", foregroundColor: .teal)
        } header: {
          SectionTitleView(title: "When did it end?")
        }
      }
    }
    .animation(.default, value: resolved)
    .navigationTitle("New Headache")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", action: dismiss)
          .disabled(isSaving)
      }
      
      ToolbarItem(placement: .confirmationAction) {
        AsyncButton("Save", mode: .replacingContent, action: save)
          .disabled(!valid)
      }
    }
  }
  
  init() {
    now = Date()
    onset = now
    end = now
  }
}

extension AddHeadacheView {
  
  private func changeSeverity(_ severity: Headache.Severity) {
    withAnimation { self.severity = severity }
  }
  
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
  }
  
  private func save() async throws {
    guard let severity = severity else {
      return
    }
    
    await MainActor.run {
      withAnimation { isSaving = true }
    }
    
    try await headacheManager.createHeadache(severity: severity, start: onset, end: resolved ? end : nil)
    
    await MainActor.run {
      withAnimation { isSaving = false }
    }
    
    dismiss()
  }
  
}

struct AddHeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AddHeadacheView()
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
        .environmentObject(Previewing.Prediction.predictor)
        .environmentObject(Previewing.healthKitManager)
    }
  }
}
