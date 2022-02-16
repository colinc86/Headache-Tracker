//
//  HeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI
import SwiftUICharts

/// Displays information about a specific headache.
struct HeadacheView: View {
  
  // MARK: Public properties
  
  @StateObject var headache: Headache
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
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
        BarChart()
          .data(headache.severitySignal)
          .chartStyle(ChartStyle(backgroundColor: .clear, foregroundColor: ColorGradient(headache.severityColorRange.first!, headache.severityColorRange.last!)))
          .frame(height: 200.0)
        
        if headache.severities?.count ?? 0 > 1 {
          ForEach(headache.severitiesArray, id: \.self) { severity in
            NavigationLink {
              SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: true)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(headacheManager)
            } label: {
              SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formatted() ?? "N/A")
            }
          }
          .onDelete(perform: deleteSeverities)
        }
        else if let severity = headache.severitiesArray.first {
          NavigationLink {
            SeverityView(severity: severity, canEditEndTime: severity == headache.severitiesArray.last, canDelete: false)
              .environment(\.managedObjectContext, viewContext)
              .environmentObject(headacheManager)
          } label: {
            SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formatted() ?? "N/A")
          }
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
    .onDisappear(perform: disappeared)
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
  
  /// Adds a severity to the headache.
  private func addSeverity() {
    if let identifier = headache.identifier {
      headacheManager.addSeverityToHeadache(identifier: identifier) { error in
        DispatchQueue.main.async {
          if let error = error {
            showAlert("Unable to Add Severity", error.localizedDescription)
          }
        }
      }
    }
  }
  
  /// Deletes the severities at the given offsets.
  ///
  /// - Parameter offsets: The item offsets.
  private func deleteSeverities(offsets: IndexSet) {
    withAnimation {
      offsets.map { headache.severitiesArray[$0] }.forEach({ headacheManager.deleteSeverity(identifier: $0.identifier ?? UUID()) })
    }
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
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
  }
}
