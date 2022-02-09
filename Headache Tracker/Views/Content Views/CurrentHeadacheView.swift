//
//  CurrentHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI
import CoreData
import DataController
import HealthKit
import Logger

/// Shows and manages the current headache's UI.
struct CurrentHeadacheView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's alert manager for displaying notifications.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The Apple Health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
    
  /// The headaches fetch request.
  /// Should only return one headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  /// Whether or not the reset confirmation alert is visible.
  @State private var showingResetConfirmation = false
  
  /// The current (unresolved) headache.
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      Form {
        Section {
          SubtitleCell(title: "Severity", subtitle: (currentHeadache?.severity ?? .notPresent).title)
          
          if let currentHeadache = currentHeadache {
            SubtitleCell(title: "Last Updated", subtitle: currentHeadache.startTime?.formatted() ?? "N/A")
            
            HStack {
              Spacer()
              Button("Reset", action: resetConfirmation)
              Spacer()
            }
          }
        }
        
        Section("Severity") {
          Button(HKCategoryValueSeverity.severe.title) { changeSeverity(to: .severe) }
          .disabled(currentHeadache?.severity == .severe)
          
          Button(HKCategoryValueSeverity.moderate.title) { changeSeverity(to: .moderate) }
          .disabled(currentHeadache?.severity == .moderate)
          
          Button(HKCategoryValueSeverity.mild.title) { changeSeverity(to: .mild) }
          .disabled(currentHeadache?.severity == .mild)
          
          Button(HKCategoryValueSeverity.unspecified.title) { changeSeverity(to: .unspecified) }
          .disabled(currentHeadache?.severity == .unspecified)
          
          Button(HKCategoryValueSeverity.notPresent.title) { changeSeverity(to: .notPresent) }
          .disabled(currentHeadache == nil)
        }
      }
      .navigationTitle("Current Headache")
    }
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .destructiveConfirmationDialog(title: alertTitle, isPresented: $showingResetConfirmation, destructiveActionTitle: "Reset", destructiveAction: {
      reset()
      withAnimation { showingResetConfirmation = false }
    })
  }
  
}

// MARK: Private methods

extension CurrentHeadacheView {
  
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
    withAnimation { showingResetConfirmation = true }
  }
  
  /// Changes the current headache's severity or creates a new headache if one
  /// doesn't exist.
  ///
  /// - Parameter severity: The new severity.
  private func changeSeverity(to severity: HKCategoryValueSeverity) {
    headacheManager.changeSeverity(to: severity) { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Update Severity", error.localizedDescription)
        }
      }
    }
  }
  
  /// Resets the current headache by deleting it.
  private func reset() {
    headacheManager.reset { error in
      if let error = error {
        DispatchQueue.main.async {
          showAlert("Unable to Reset Headache", error.localizedDescription)
        }
      }
    }
  }
  
  /// Displays the reset confirmation alert to the user.
  private func resetConfirmation() {
    if healthIntegration {
      showResetConfirmation("Reset Headache and any associated Health app data?")
    }
    else {
      showResetConfirmation("Reset Headache?")
    }
  }
  
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    CurrentHeadacheView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
  }
}
