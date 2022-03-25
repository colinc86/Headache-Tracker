//
//  CurrentHeadacheViews.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct CurrentHeadacheViews: View {
  
  /// The view's headache.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// Whether the type view should be shown.
  @AppStorage(AppSettings.ListOptions.type) private var showTypeView = true
  
  /// Whether the onset view should be shown.
  @AppStorage(AppSettings.ListOptions.onset) private var showOnsetView = true
  
  /// Whether the duration view should be shown.
  @AppStorage(AppSettings.ListOptions.duration) private var showDurationView = true
  
  /// Whether the progression view should be shown.
  @AppStorage(AppSettings.ListOptions.progression) private var showProgressionView = true
  
  /// Whether the notes view should be shown.
  @AppStorage(AppSettings.ListOptions.notes) private var showNotesView = true
  
  /// Whether the tags view should be shown.
  @AppStorage(AppSettings.ListOptions.tags) private var showTagsView = true
  
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
  
  /// Whether the edit notes view is visible.
  @State private var showingEditNotesView = false
  
  /// Whether the edit tags view is visible.
  @State private var showingEditTagsView = false
  
  var body: some View {
    Group {
      // Resolve the Headache
      Section {
        ActionView(title: "Resolve Headache", buttonTitle: "Resolve", systemImage: "face.smiling.fill", foregroundColor: .teal, action: resolveConfirmation)
      } footer: {
        Text("Is your headache gone? Tap Resolve to let the app know.")
      }
      
//      if showTypeView {
//        Section {
//          TypeCardView(type: <#T##HeadacheType#>, classification: <#T##HeadacheClassification#>, editButtonAction: <#T##(() -> Void)?##(() -> Void)?##() -> Void#>)
//        }
//      }
      
      // Onset
      if showOnsetView, let onset = headache.startTime {
        Section {
          OnsetView(onset: onset)
        }
      }
      
      // Duration
      if showDurationView {
        Section {
          DurationView(headache: headache)
        }
      }
      
      // Progression
      if showProgressionView, headache.severitiesArray.count > 1 {
        Section {
          ProgressionView(headache: headache)
        }
      }
      
      // Notes
      if showNotesView {
        Section {
          NotesView(notes: headache.notes, editButtonAction: editNotesAction)
        }
      }
      
      // Tags
      if showTagsView {
        Section {
          TagsCardView(tags: headache.tagValues, editAction: editTagsAction, tagAction: { _ in })
        }
      }
    }
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .confirmationDialog("Resolve Headache? It will be available in the Headaches tab.", isPresented: $showingResolveConfirmation, titleVisibility: .visible) {
      AsyncButton("Resolve", role: .destructive, action: resolve)
    }
    .sheet(isPresented: $showingEditNotesView) {
      EditNotesView(notes: headache.notes ?? "", identifier: headache.identifier ?? UUID())
    }
    .sheet(isPresented: $showingEditTagsView) {
      EditTagsView(tags: headache.tagsArray.map({ $0.value ?? "" }), identifier: headache.identifier ?? UUID())
    }
  }
}

extension CurrentHeadacheViews {
  
  private func editNotesAction() {
    withAnimation { showingEditNotesView = true }
  }
  
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
  
}

struct CurrentHeadacheViews_Previews: PreviewProvider {
  static var previews: some View {
    List {
      CurrentHeadacheViews(headache: Previewing.CoreData.resolvedHeadache)
        .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
        .environmentObject(Previewing.headacheManager)
        .environmentObject(Previewing.alertManager)
    }
  }
}
