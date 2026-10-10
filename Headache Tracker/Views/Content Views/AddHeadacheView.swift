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

  /// The app's color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: viewModel.severity, mode: .action(viewModel.setSeverity))
          .cardListRow()
      } header: {
        SectionTitleView(title: "How severe was the headache?")
      } footer: {
        SectionFooterView(title: "You can modify this and add more values later.")
      }
      
      Section {
        EditableDateTimeCard(title: "Onset", foregroundColor: colorTheme.purple, date: $viewModel.onset)
          .cardListRow()
      } header: {
        SectionTitleView(title: "When did it start?")
      }
      
      Section {
        Toggle("Resolved", isOn: $viewModel.resolved)
          .tint(colorTheme.baseColor)
      } header: {
        SectionTitleView(title: "Has it resolved?")
      }
      
      if viewModel.resolved {
        Section {
          EditableDateTimeCard(title: "End", foregroundColor: colorTheme.teal, date: $viewModel.end)
            .cardListRow()
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
    // A resolved headache also needs a valid interval — `createHeadache`
    // rejects start >= end, so keep Save disabled rather than erroring on tap.
    return severity != nil && onset < Date() && (!resolved || onset < end)
  }
  
  /// Sets the severity.
  @MainActor func setSeverity(_ severity: Headache.Severity) {
    withAnimation { self.severity = severity }
  }
  
  /// Saves the headache.
  ///
  /// `@MainActor` so the `isSaving` state runs on the main thread; the `defer`
  /// resets it on every exit so a failed `createHeadache` (which throws to the
  /// AsyncButton's alert) re-enables Cancel instead of trapping the user.
  @MainActor func save() async throws {
    guard let severity = severity else { return }
    withAnimation { isSaving = true }
    defer { isSaving = false }

    try await headacheManager.createHeadache(
      severity: severity,
      start: onset,
      end: resolved ? end : nil)

    // A new *open* headache becomes the current one, so start its lock-screen
    // Live Activity. `createHeadache` already mirrored the widget and HealthKit,
    // but the Live Activity is app-only and can't be reconciled from the
    // shared manager. (A resolved past-log entry has no active headache.)
    if !resolved {
      await LiveActivityManager.shared.reconcile(headacheManager: headacheManager)
    }
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
