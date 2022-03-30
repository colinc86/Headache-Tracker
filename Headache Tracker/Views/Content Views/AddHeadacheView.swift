//
//  AddHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/14/22.
//

import SwiftUI

struct AddHeadacheView: View {
  
  // MARK: Types
  
  class ViewModel: ObservableObject {
    
    /// The selected severity.
    @Published var severity: Headache.Severity? = nil
    
    /// The onset date.
    @Published var onset = Date()
    
    /// The end date.
    @Published var end = Date()
    
    /// Whether or not the headache was resolved.
    @Published var resolved = false
    
    /// Whether or not the view is saving its data.
    @Published var isSaving = false
    
    /// Whether or not the view's data is valid.
    var validData: Bool {
      return severity != nil && onset < Date()
    }
    
  }
  
  // MARK: Private properties
  
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The view's model.
  @ObservedObject private var viewModel = ViewModel()
  
  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: viewModel.severity, action: changeSeverity)
      } header: {
        SectionTitleView(title: "How severe was the headache?")
      } footer: {
        Text("You can modify this and add more values later.")
      }
      
      Section {
        EditableDateTimeCard(title: "Onset", foregroundColor: .purple, date: $viewModel.onset)
      } header: {
        SectionTitleView(title: "When did it start?")
      }
      
      Section {
        Toggle("Resolved", isOn: $viewModel.resolved)
          .tint(.accentColor)
      } header: {
        SectionTitleView(title: "Has it resolved?")
      }
      
      if viewModel.resolved {
        Section {
          EditableDateTimeCard(title: "End", foregroundColor: .teal, date: $viewModel.end)
        } header: {
          SectionTitleView(title: "When did it end?")
        }
      }
    }
    .animation(.default, value: viewModel.resolved)
    .navigationTitle("New Headache")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", action: dismiss)
          .disabled(viewModel.isSaving)
      }
      
      ToolbarItem(placement: .confirmationAction) {
        AsyncButton("Save", mode: .replacingContent, action: save)
          .disabled(!viewModel.validData)
      }
    }
  }
  
}

extension AddHeadacheView {
  
  private func changeSeverity(_ severity: Headache.Severity) {
    withAnimation { viewModel.severity = severity }
  }
  
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
  }
  
  private func save() async throws {
    guard let severity = viewModel.severity else {
      return
    }
    
    await MainActor.run {
      withAnimation { viewModel.isSaving = true }
    }
    
    try await headacheManager.createHeadache(severity: severity, start: viewModel.onset, end: viewModel.resolved ? viewModel.end : nil)
    
    await MainActor.run {
      withAnimation { viewModel.isSaving = false }
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
