//
//  HeadacheViews.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct HeadacheViews: View {
  
  /// The view's headache.
  @StateObject var headache: Headache
  
  /// Whether the view should allow headache resolution.
  var allowsResolution: Bool = false
  
  /// Whether the view should allow editing of headache severities.
  var allowsEditing: Bool = false
  
  /// Whether the view should allow the user to delete the headache.
  var allowsDeletion: Bool = false
  
  /// Whether the view should show all cards regardless of view options.
  var showsAllCards: Bool = false
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  /// Whether the resolve confirmation alert is visible.
  @State private var showingResolveConfirmation = false
  
  /// Whether or not the delete confirmation alert is visible.
  @State private var showingDeleteConfirmation = false
  
  /// Whether or not the delete health data confirmation alert is visible.
  @State private var showingDeleteHealthDataConfirmation = false
  
  /// Whether the edit type view is visible.
  @State private var showingEditTypeView = false
  
  /// Whether the edit notes view is visible.
  @State private var showingEditNotesView = false
  
  /// Whether the edit tags view is visible.
  @State private var showingEditTagsView = false
  
  @State private var expandedProgressionView = false
  
  // Preferences
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  @AppStorage(Preferences.Lists.Keys.type) private var showTypeView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.onset) private var showOnsetView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.duration) private var showDurationView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.progression) private var showProgressionView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.notes) private var showNotesView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Lists.Keys.tags) private var showTagsView = Preferences.Lists.Defaults.shown
  @AppStorage(Preferences.Health.Keys.enabled) private var healthEnabled = Preferences.Health.Defaults.enabled
  @AppStorage(Preferences.Health.Keys.deleteDisposition) private var deleteDisposition = Preferences.Health.Defaults.deleteDisposition
  
  var body: some View {
    Group {
      if allowsResolution {
        // Resolve the Headache
        Section {
          ActionCard(title: "Resolve Headache", buttonTitle: "Resolve", systemImage: "face.smiling.fill", action: resolveConfirmation)
        } footer: {
          Text("Is your headache gone? Tap Resolve to let the app know.")
        }
      }
      else {
        Section {
          StatusCard(resolved: headache.resolved)
        }
      }
      
      if showsAllCards || showTypeView {
        Section {
          TypeCard(type: headache.headacheType, classification: headache.headacheClassification, editAction: editTypeAction)
        }
      }
      
      // Onset
      if showsAllCards || showOnsetView, let onset = headache.startTime {
        Section {
          OnsetCard(onset: onset)
        }
      }
      
      // Duration
      if showsAllCards || showDurationView {
        Section {
          DurationCard(headache: headache)
        }
      }
      
      // Progression
      if showsAllCards || showProgressionView {
        Section {
          ProgressionCard(headache: headache, expanded: $expandedProgressionView)
        }
//        if allowsEditing {
//          if headache.progression.count > 1 {
//            ProgressionCard(headache: headache)
//
//            ForEach(headache.severitiesArray, id: \.self) { severity in
//              NavigationLink {
//                SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: true)
//              } label: {
//                SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formattedNonRelative() ?? "N/A")
//              }
//            }
//            .onDelete(perform: deleteSeverities)
//          }
//          else if let severity = headache.severitiesArray.first {
//            NavigationLink {
//              SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: false)
//            } label: {
//              SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formattedNonRelative() ?? "N/A")
//            }
//          }
//        }
//        else if headache.progression.count > 1 {
//          Section {
//            ProgressionCard(headache: headache)
//          }
//        }
      }
      
      // Notes
      if showsAllCards || showNotesView {
        Section {
          NotesCard(notes: headache.notes ?? "", editAction: editNotesAction)
        }
      }
      
      // Tags
      if showsAllCards || showTagsView {
        Section {
          TagsCard(tags: headache.tagValues, editAction: editTagsAction, tagAction: { _ in })
        }
      }
      
      if allowsDeletion {
        Section {
          HStack {
            Spacer()
            Button("Delete Headache", action: deleteConfirmation)
              .foregroundColor(.red)
            Spacer()
          }
        }
      }
    }
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .confirmationDialog("Resolve Headache? It will be available in the Headaches tab.", isPresented: $showingResolveConfirmation, titleVisibility: .visible) {
      AsyncButton("Resolve", role: .destructive, action: resolve)
    }
    .confirmationDialog("Delete Headache", isPresented: $showingDeleteConfirmation, actions: {
      switch deleteDisposition {
      case .always:
        Button("Delete", role: .destructive) {
          delete(deleteHealthKitData: true)
        }
      case .never:
        Button("Delete", role: .destructive) {
          delete(deleteHealthKitData: false)
        }
      case .ask:
        if healthEnabled {
          Button("Delete", role: .destructive) {
            showingDeleteHealthDataConfirmation = true
          }
        }
        else {
          Button("Delete", role: .destructive) {
            delete(deleteHealthKitData: true)
          }
        }
      }
    }, message: {
      switch deleteDisposition {
      case .always:
        if healthEnabled {
          Text("Delete the headache and its associated Health data?")
        }
        else {
          Text("Delete the headache?")
        }
      case .never:
        if healthEnabled {
          Text("Delete the headache without deleting its associated Health data?")
        }
        else {
          Text("Delete the headache?")
        }
      case .ask:
        Text("Delete the headache?")
      }
    })
    .confirmationDialog("Delete Headache", isPresented: $showingDeleteHealthDataConfirmation, actions: {
      Button("Yes", role: .destructive) {
        delete(deleteHealthKitData: true)
      }
      Button("No") {
        delete(deleteHealthKitData: false)
      }
    }, message: {
      Text("Delete the headache's associated Health data?")
    })
    .sheet(isPresented: $showingEditTypeView) {
      EditTypeView(type: headache.headacheType, classification: headache.headacheClassification, identifier: headache.identifier ?? UUID())
        .accentColor(colorTheme.baseColor)
    }
    .sheet(isPresented: $showingEditNotesView) {
      EditNotesView(notes: headache.notes ?? "", identifier: headache.identifier ?? UUID())
        .accentColor(colorTheme.baseColor)
    }
    .sheet(isPresented: $showingEditTagsView) {
      EditTagsView(tags: headache.tagsArray.map({ $0.value ?? "" }), identifier: headache.identifier ?? UUID())
        .accentColor(colorTheme.baseColor)
    }
  }
}

// MARK: Private methods

extension HeadacheViews {
  
  /// The edit type action.
  private func editTypeAction() {
    withAnimation { showingEditTypeView = true }
  }
  
  /// The edit notes action.
  private func editNotesAction() {
    withAnimation { showingEditNotesView = true }
  }
  
  /// The edit tags action.
  private func editTagsAction() {
    withAnimation { showingEditTagsView = true }
  }
  
  /// Displays the reset confirmation alert to the user.
  private func resolveConfirmation() {
    withAnimation { showingResolveConfirmation = true }
  }
  
  /// Resolves the current headache.
  private func resolve() async throws {
    logDebug("Resolve current headache.")
    
    // Resolve the headache
    try await headacheManager.resolve()
    
    // Remove any pending alerts
    alertManager.removeRequests(pending: true, delivered: false)
  }
  
  /// Shows an alert to the user.
  ///
  /// - Parameters:
  ///   - title: The alert's title.
  ///   - message: The alert's message.
  private func showAlert(_ title: String, _ error: Error) {
    alertTitle = title
    alertMessage = error.localizedDescription
    withAnimation { showingAlert = true }
  }
  
  /// Displays a delete confirmation to the user.
  private func deleteConfirmation() {
    withAnimation { showingDeleteConfirmation = true }
  }
  
  /// Deletes the severities at the given offsets.
  ///
  /// - Parameter offsets: The item offsets.
  private func deleteSeverities(offsets: IndexSet) {
    withAnimation {
      offsets.map { headache.severitiesArray[$0] }.forEach({ headache in
        Task {
          do {
            try await headacheManager.deleteSeverity(identifier: headache.identifier)
          }
          catch {
            showAlert("Unable to Delete Severity", error)
          }
        }
      })
    }
  }
  
  /// Deletes the view's headache.
  ///
  /// - Parameter deleteHealthKitData: Whether the headache's associated health kit
  ///   data should be deleted.
  private func delete(deleteHealthKitData: Bool) {
    if let identifier = headache.identifier {
      Task {
        do {
          // Delete the headache
          try await headacheManager.deleteHeadache(identifier: identifier, deleteHealthKitData: deleteHealthKitData)
          
          // Remove any alerts
          if !headache.resolved {
            alertManager.removeRequests(pending: true, delivered: false)
          }
          
          // Dismiss the view
          presentationMode.wrappedValue.dismiss()
        }
        catch {
          showAlert("Unable to Delete Headache", error)
        }
      }
    }
  }
  
}

struct CurrentHeadacheViews_Previews: PreviewProvider {
  static var previews: some View {
    List {
      HeadacheViews(headache: Previewing.CoreData.resolvedHeadache, allowsResolution: true, allowsEditing: true, allowsDeletion: true, showsAllCards: true)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
    }
  }
}
