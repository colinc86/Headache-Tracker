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
  
  var body: some View {
    Group {
      // Onset
      if let onset = headache.startTime {
        Section {
          OnsetView(onset: onset)
        }
      }
      
      // Duration
      Section {
        DurationView(headache: headache)
      }
      
      // Progression
      if headache.severitiesArray.count > 1 {
        Section {
          TitleCaptionView(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: .orange) {
            LineGraph(series: headache.severitySignal, gradient: Gradient(colors: headache.severityColorRange))
              .frame(height: 100)
          }
        }
      }
      
      // Resolve the Headache
      Section {
        ActionView(title: "Resolve Headache", buttonTitle: "Resolve", systemImage: "face.smiling.fill", foregroundColor: .teal, action: resolveConfirmation)
      } footer: {
        Text("Is your headache gone? Tap Resolve to let the app know.")
      }
    }
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .confirmationDialog("Resolve Headache? It will be available in the Headaches tab.", isPresented: $showingResolveConfirmation, titleVisibility: .visible) {
      AsyncButton("Resolve", role: .destructive, action: resolve)
    }
  }
}

extension CurrentHeadacheViews {
  
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
