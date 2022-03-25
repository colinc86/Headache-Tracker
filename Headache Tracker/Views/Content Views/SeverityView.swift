//
//  SeverityView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import SwiftUI

struct SeverityView: View {
  
  // MARK: Public properties
  
  /// The severity to display in the view.
  @StateObject var severity: SeverityState
  
  /// Whether or not the end time can be edited.
  let canEditEndTime: Bool
  
  /// Whether or not the severity can be deleted.
  let canDelete: Bool
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The editing state of the view.
  @State private var editing = false
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  /// Whether or not the delete confirmation alert is visible.
  @State private var showingDeleteConfirmation = false
  
  /// The current edit severity.
  @State private var editSeverity = Headache.Severity.notPresent
  
  /// The current edit start time.
  @State private var editStartTime = Date()
  
  /// The current edit end time.
  @State private var editEndTime = Date()
  
  // MARK: View body
  
  var body: some View {
    List {
      Section {
        if let location = severity.trainingDataArray.first?.location?.location {
          MapCell(location: location)
        }
        
        if editing {
          Picker("Severity", selection: $editSeverity) {
            Text("Not Present").tag(Headache.Severity.notPresent)
            Text("Present").tag(Headache.Severity.unspecified)
            Text("Mild").tag(Headache.Severity.mild)
            Text("Moderate").tag(Headache.Severity.moderate)
            Text("Severe").tag(Headache.Severity.severe)
          }
          
          DatePicker("Start Time", selection: $editStartTime, displayedComponents: [.date, .hourAndMinute])
          
          if canEditEndTime {
            DatePicker("End Time", selection: $editEndTime, displayedComponents: [.date, .hourAndMinute])
          }
          else {
            SubtitleCell(title: "End Time", subtitle: severity.endTime?.formattedNonRelative() ?? "N/A")
          }
        }
        else {
          SubtitleCell(title: "Severity", subtitle: severity.severity.title)
          SubtitleCell(title: "Start Time", subtitle: severity.startTime?.formattedNonRelative() ?? "N/A")
          SubtitleCell(title: "End Time", subtitle: severity.endTime?.formattedNonRelative() ?? "N/A")
        }
      }
      
      Section {
        HStack {
          Spacer()
          Button("Delete Severity", action: deleteConfirmation)
            .foregroundColor(canDelete ? .red : .secondary)
            .disabled(!canDelete)
          Spacer()
        }
      } footer: {
        if !canDelete {
          Text("You can't delete the only severity logged in a headache.")
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        if editing {
          Button("Cancel", action: cancel)
        }
        else {
          EmptyView()
        }
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
        if editing {
          Button("Save", action: save)
        }
        else {
          Button("Edit", action: edit)
        }
      }
    }
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .destructiveConfirmationDialog(title: alertTitle, isPresented: $showingDeleteConfirmation, destructiveActionTitle: "Delete", destructiveAction: {
      delete()
      withAnimation { showingDeleteConfirmation = false }
    })
  }
  
}

// MARK: Private methods

extension SeverityView {
  
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
  
  /// Shows a reset confirmation dialog to the user.
  ///
  /// - Parameter title: The dialog's title.
  private func showResetConfirmation(_ title: String) {
    alertTitle = title
    withAnimation { showingDeleteConfirmation = true }
  }
  
  /// Cancel editing.
  private func cancel() {
    withAnimation { editing = false }
  }
  
  /// Sets the view's edit mode.
  private func edit() {
    editSeverity = severity.severity
    editStartTime = severity.startTime ?? Date()
    editEndTime = severity.endTime ?? Date()
    
    withAnimation {
      editing = true
    }
  }
  
  /// Saves the severity.
  private func save() {
    withAnimation {
      editing = false
    }
    
    if let identifier = severity.identifier {
      Task {
        do {
          try await headacheManager.updateSeverity(identifier: identifier, value: editSeverity, startTime: editStartTime, endTime: editEndTime)
        }
        catch {
          showAlert("Error Saving Severity", error)
        }
      }
    }
  }
  
  /// Deletes the view's severity.
  private func delete() {
    if let identifier = severity.identifier {
      Task {
        do {
          try await headacheManager.deleteSeverity(identifier: identifier)
          presentationMode.wrappedValue.dismiss()
        }
        catch {
          showAlert("Unable to Delete Severity", error)
        }
      }
    }
  }
  
  /// Displays a delete confirmation to the user.
  private func deleteConfirmation() {
    if healthIntegration {
      showResetConfirmation("Are you sure you want to delete the severity and its associated Health app data?")
    }
    else {
      showResetConfirmation("Are you sure you want to delete the severity?")
    }
  }
  
}

struct SeverityView_Previews: PreviewProvider {
  static var previews: some View {
    SeverityView(severity: Previewing.CoreData.severity, canEditEndTime: true, canDelete: true)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
