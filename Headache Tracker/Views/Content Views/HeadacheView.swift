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
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false

  // MARK: View body
  
  var body: some View {
    List {
      Section {
        SeveritySelectionView(currentSeverity: nil, severityRange: headache.severityRange, collapsed: true)
          .cardListRow()
      } header: {
        SectionTitleView(title: "Headache")
      } footer: {
        if !headache.resolved, let startTime = headache.severitiesArray.last?.startTime {
          SectionFooterView(title: "Last updated \(startTime.formattedNonRelative())")
        }
      }
      
      HeadacheViews(headache: headache, allowsResolution: false, allowsEditing: true, allowsDeletion: true, showsAllCards: true)
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
    .navigationBarTitleDisplayMode(.inline)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
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

}

struct HeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheView(headache: Previewing.CoreData.resolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
    
    HeadacheView(headache: Previewing.CoreData.unresolvedHeadache)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
  }
}
