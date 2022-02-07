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

struct CurrentHeadacheView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject private var headacheManager: HeadacheManager
  @EnvironmentObject private var alertManager: AlertManager
  
  @AppStorage(AppSettings.checkInAlerts) private var checkInAlerts = false
  @AppStorage(AppSettings.checkInInterval) private var checkInInterval = TimeInterval(3600.0)
    
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  @State var alertTitle = ""
  @State var alertMessage = ""
  @State var showingAlert = false
  
  var body: some View {
    NavigationView {
      Form {
        Section {
          SubtitleCell(title: "Severity", subtitle: (currentHeadache?.severity ?? .notPresent).title)
          
          if let currentHeadache = currentHeadache {
            SubtitleCell(title: "Last Updated", subtitle: currentHeadache.startTime?.formatted() ?? "N/A")
            
            HStack {
              Spacer()
              Button("Reset", action: reset)
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
    .alert(alertTitle, isPresented: $showingAlert) {
      Button("OK", action: { showingAlert = false })
    } message: {
      Text(alertMessage)
    }
  }
  
}

// MARK: Private methods

extension CurrentHeadacheView {
  
  private func showAlert(_ title: String, _ message: String) {
    alertTitle = title
    alertMessage = message
    showingAlert = true
  }
  
  private func changeSeverity(to severity: HKCategoryValueSeverity) {
    headacheManager.changeSeverity(to: severity) { error in
      if let error = error {
        showAlert("Unable to Update Severity", error.localizedDescription)
      }
      else {
        // Cancel any pending notifications
        alertManager.removeRequests(pending: true, delivered: false)
        
        // Schedule a new notification if this was a non-`not present` severity
        if severity == .notPresent {
          logDebug("Not presenting alert because severity was \"not present\".")
        }
        else if checkInAlerts {
          let futureDate = Date(timeIntervalSinceNow: checkInInterval)
          let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)
          
          logDebug("Presenting alert with components at date \(futureDate).")
          
          alertManager.presentAlert(
            with: HeadacheAlertRequest.checkIn(headacheIdentifier: currentHeadache?.identifier ?? UUID()),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
            badgeNumber: 0) { error in
              if let error = error {
                logError("Error creating notification: \(error)")
              }
              else {
                logDebug("Added alert to the alert manager.")
              }
            }
        }
        else {
          logDebug("Not presenting alert because checkInAlerts was false.")
        }
      }
    }
  }
  
  private func reset() {
    headacheManager.reset { error in
      if let error = error {
        showAlert("Unable to Reset Headache", error.localizedDescription)
      }
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
