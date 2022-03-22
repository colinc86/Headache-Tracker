//
//  HeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

/// Displays information about a specific headache.
struct HeadacheView: View {
  
  // MARK: Public properties
  
  /// The view's headache to display.
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  /// Whether or not the delete confirmation alert is visible.
  @State private var showingDeleteConfirmation = false
  
  /// Whether the edit notes view is visible.
  @State private var showingEditNotesView = false
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  private let durationUpdateWaiter = Waiter()
  
  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: nil, severityRange: headache.severityRange, collapsed: true)
      } header: {
        SectionTitleView(title: "Headache")
      } footer: {
        if !headache.resolved, let startTime = headache.severitiesArray.last?.startTime {
          Text("Last updated \(startTime.formattedNonRelative())")
        }
      }
      
      Section {
        StatusView(resolved: headache.resolved)
      }
      
      if let onset = headache.startTime {
        Section {
          OnsetView(onset: onset, relativeDate: !headache.resolved)
        }
      }
      
      Section {
        DurationView(headache: headache)
      }
      
      Section {
        if headache.severities?.count ?? 0 > 1 {
          ProgressionView(headache: headache)
          
          ForEach(headache.severitiesArray, id: \.self) { severity in
            NavigationLink {
              SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: true)
            } label: {
              SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formattedNonRelative() ?? "N/A")
            }
          }
          .onDelete(perform: deleteSeverities)
        }
        else if let severity = headache.severitiesArray.first {
          NavigationLink {
            SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: false)
          } label: {
            SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formattedNonRelative() ?? "N/A")
          }
        }
      }
      
      Section {
        NotesView(notes: headache.notes, editButtonAction: editNotesAction)
      }
      
      Section {
        HStack {
          Spacer()
          Button("Delete Headache", action: deleteConfirmation)
            .foregroundColor(.red)
          Spacer()
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: addSeverity) {
          Label("Add Severity", systemImage: "plus")
        }
        .disabled(!headache.resolved)
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
        EditButton()
          .disabled(headache.severities?.count ?? 0 <= 1 || !headache.resolved)
      }
    }
    .onAppear(perform: appeared)
    .onDisappear(perform: durationUpdateWaiter.stop)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .destructiveConfirmationDialog(title: alertTitle, isPresented: $showingDeleteConfirmation, destructiveActionTitle: "Delete", destructiveAction: {
      delete()
      withAnimation { showingDeleteConfirmation = false }
    })
    .sheet(isPresented: $showingEditNotesView) {
      EditNotesView(notes: headache.notes, identifier: headache.identifier)
    }
  }
  
}

// MARK: Private methods

extension HeadacheView {
  
  /// Shows an alert to the user.
  ///
  /// - Parameters:
  ///   - title: The alert's title.
  ///   - message: The alert's message.
  private func showAlert(_ title: String, _ message: String) {
    alertTitle = title
    alertMessage = message
    withAnimation { showingAlert = true }
  }
  
  /// Shows a reset confirmation dialog to the user.
  ///
  /// - Parameter title: The dialog's title.
  private func showResetConfirmation(_ title: String) {
    alertTitle = title
    withAnimation { showingDeleteConfirmation = true }
  }
  
  /// Adds a severity to the headache.
  private func addSeverity() {
    if let identifier = headache.identifier {
      Task {
        do {
          try await headacheManager.addSeverityToHeadache(identifier: identifier)
        }
        catch {
          showAlert("Unable to Add Severity", error.localizedDescription)
        }
      }
    }
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
            showAlert("Unable to Delete Severity", error.localizedDescription)
          }
        }
      })
    }
  }
  
  /// Deletes the view's headache.
  private func delete() {
    if let identifier = headache.identifier {
      Task {
        do {
          // Delete the headache
          try await headacheManager.deleteHeadache(identifier: identifier)
          
          // Remove any alerts
          if !headache.resolved {
            alertManager.removeRequests(pending: true, delivered: false)
          }
          
          // Dismiss the view
          presentationMode.wrappedValue.dismiss()
        }
        catch {
          showAlert("Unable to Delete Headache", error.localizedDescription)
        }
      }
    }
  }
  
  /// Displays a delete confirmation to the user.
  private func deleteConfirmation() {
    if healthIntegration {
      showResetConfirmation("Are you sure you want to delete the headache and its associated Health app data?")
    }
    else {
      showResetConfirmation("Are you sure you want to delete the headache?")
    }
  }
  
  /// Updates the duration view's identifier.
  func updateDurationID() {
    DispatchQueue.main.async {
      withAnimation { durationID = UUID() }
    }
  }
  
  /// Called when the view appears.
  func appeared() {
    if !headache.resolved {
      updateDurationID()
      durationUpdateWaiter.wait(for: 60.0, repeats: true, completion: updateDurationID)
    }
  }
  
  private func editNotesAction() {
    withAnimation { showingEditNotesView = true }
  }
  
}

struct HeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheView(headache: Previewing.CoreData.resolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
    
    HeadacheView(headache: Previewing.CoreData.unresolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
