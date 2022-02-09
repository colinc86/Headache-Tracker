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
  
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var mode: Binding<PresentationMode>
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
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
  
  /// The id of the duration view.
  @State private var durationID = UUID()
  
  /// A timer to update the duration view for unresolved headaches.
  @State private var durationUpdateTimer: Timer?
  
  // MARK: View body
  
  var body: some View {
    List {
      Section("Headache") {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formatted() ?? "N/A")
        SubtitleCell(title: "Duration", subtitle: Formatters.dateComponentsFormatter.string(from: headache.duration) ?? "0 min")
          .id(durationID)
        
        SubtitleCell(title: "Severity", subtitle: headache.severityDescription)
        SubtitleCell(title: "Status", subtitle: headache.resolved ? "Resolved" : "Unresolved")
      }
      
      Section("Progression") {
        ForEach(headache.severitiesArray, id: \.self) { severity in
          SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formatted() ?? "N/A")
        }
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
    .onAppear(perform: appeared)
    .onDisappear(perform: disappeared)
    .navigationTitle("Headache")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .destructiveConfirmationDialog(title: alertTitle, isPresented: $showingDeleteConfirmation, destructiveActionTitle: "Delete", destructiveAction: {
      delete()
      withAnimation { showingDeleteConfirmation = false }
    })
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
  
  /// Deletes the view's headache.
  private func delete() {
    if let identifier = headache.identifier {
      headacheManager.deleteHeadache(identifier: identifier) { error in
        DispatchQueue.main.async {
          if let error = error {
            showAlert("Unable to Delete Headache", error.localizedDescription)
          }
          else {
            mode.wrappedValue.dismiss()
          }
        }
      }
    }
  }
  
  /// Displays a delete confirmation to the user.
  private func deleteConfirmation() {
    if healthIntegration {
      showResetConfirmation("Are you sure you want to delete the headache and any associated Health app data?")
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
      startDurationUpdateTimer()
    }
  }
  
  /// Called when the view disappears.
  func disappeared() {
    stopDurationUpdateTimer()
  }
  
  /// Starts the duration update timer.
  func startDurationUpdateTimer() {
    durationUpdateTimer = Timer(timeInterval: 60.0, repeats: true, block: durationUpdateTimerFired)
    durationUpdateTimer?.tolerance = 60.0 / 10.0
    RunLoop.main.add(durationUpdateTimer!, forMode: RunLoop.Mode.default)
  }
  
  /// Stops the duration update timer.
  func stopDurationUpdateTimer() {
    durationUpdateTimer?.invalidate()
    durationUpdateTimer = nil
  }
  
  /// Called when the duration update timer fires.
  func durationUpdateTimerFired(_ timer: Timer) {
    updateDurationID()
  }
  
}

struct HeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheView(headache: Previewing.CoreData.headache)
  }
}
