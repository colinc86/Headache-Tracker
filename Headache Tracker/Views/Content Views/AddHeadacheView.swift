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
    
    // MARK: Private properties
    
    /// The app's headache manager.
    private let headacheManager: HeadacheManager
    
    // MARK: Initializers
    
    /// Creates a view model.
    init(headacheManager: HeadacheManager) {
      self.headacheManager = headacheManager
    }
    
  }
  
  // MARK: Private properties
  
  @Environment(\.dismiss) private var dismiss
  
  /// The view's model.
  @ObservedObject private var viewModel: ViewModel
  
  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: viewModel.severity, action: viewModel.setSeverity)
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
        Button("Cancel") { dismiss() }
          .disabled(viewModel.isSaving)
      }
      
      ToolbarItem(placement: .confirmationAction) {
        AsyncButton("Save", mode: .replacingContent, action: save)
          .disabled(!viewModel.validData)
      }
    }
  }
  
  // MARK: Initializers
  
  init(headacheManager: HeadacheManager) {
    self.viewModel = ViewModel(headacheManager: headacheManager)
  }
  
}

// MARK: Actions

extension AddHeadacheView {

  func save() async throws {
    try await viewModel.save()
    dismiss()
  }
  
}

extension AddHeadacheView.ViewModel {
  
  /// Whether or not the view's data is valid.
  @MainActor var validData: Bool {
    return severity != nil && onset < Date()
  }
  
  /// Sets the severity.
  @MainActor func setSeverity(_ severity: Headache.Severity) {
    withAnimation { self.severity = severity }
  }
  
  /// Sets the `isSaving` property.
  @MainActor func setSaving(_ saving: Bool) {
    withAnimation { isSaving = saving }
  }
  
  /// Saves the headache.
  func save() async throws {
    guard let severity = severity else { return }
    await setSaving(true)
    
    try await headacheManager.createHeadache(
      severity: severity,
      start: onset,
      end: resolved ? end : nil)
    
    await setSaving(false)
  }
  
}

struct AddHeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      AddHeadacheView(headacheManager: Previewing.headacheManager)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
        .environmentObject(Previewing.Prediction.predictor)
        .environmentObject(Previewing.healthKitManager)
    }
  }
}
