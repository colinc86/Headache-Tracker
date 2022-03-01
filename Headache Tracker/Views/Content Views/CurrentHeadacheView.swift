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

/// Shows and manages the current headache's UI.
struct CurrentHeadacheView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// The app's alert manager for displaying notifications.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The Apple Health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
    
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
  
  /// Whether or not the resolve confirmation alert is visible.
  @State private var showingResolveConfirmation = false
  
  /// True iff the current headache is being updated.
  @State private var updatingHeadache = false
  
  /// The last error produced by prediction.
  @State private var predictionError: Error? = nil
  
  /// Whether or not the headache manager needs more not-present headache training data.
  @State private var needsInput: Bool = false
  
  /// Whether or not we are handling headache training data.
  @State private var handlingInput: Bool = false
  
  /// The application's first appearance.
  @State private var firstAppearance: Bool = true
  
  /// The current (unresolved) headache.
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  /// Called when the application becomes active.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        // New/Current Headache
        Section {
          // New/Current Severity
          HorizontalSeverityLevel(currentSeverity: currentHeadache?.severity, severityRange: nil, collapsed: false, action: changeSeverity)
        } header: {
          SectionTitleView(title: currentHeadache == nil ? "New Headache" : "Current Headache")
        } footer: {
          if let currentHeadache = currentHeadache {
            if let startTime = currentHeadache.severitiesArray.last?.startTime {
              Text("Last updated \(startTime.formattedNonRelative())")
            }
          } else {
            Text("Feel a headache coming on? Select a severity level to start tracking it.")
          }
        }
        
        // No Headache
        if currentHeadache == nil && needsInput {
          Section {
            Button("No Headache", action: noHeadacheAction)
              .buttonStyle(BorderlessButtonStyle())
              .font(.title)
              .foregroundColor(.teal)
              .cell(title: "No Headache?", systemImage: "checkmark.circle.fill", foregroundColor: .teal)
          } footer: {
            Text("No Headache? Tap above to let the app know.")
          }
        }
        // Current Headache Information
        else if let currentHeadache = currentHeadache {
          // Onset
          if let onset = currentHeadache.startTime {
            Section {
              OnsetView(onset: onset)
            }
          }
          
          // Duration
          Section {
            DurationView(headache: currentHeadache)
          }
          
          // Progression
          if currentHeadache.severitiesArray.count > 1 {
            Section {
              LineGraph(series: currentHeadache.severitySignal, gradient: Gradient(colors: currentHeadache.severityColorRange))
                .frame(height: 100)
                .cell(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: .orange)
            }
          }
          
          // Resolve the Headache
          Section {
            Button("Resolve", action: resolveConfirmation)
              .buttonStyle(BorderlessButtonStyle())
              .font(.title)
              .foregroundColor(.teal)
              .cell(title: "Resolve Headache", systemImage: "face.smiling.fill", foregroundColor: .teal)
          } footer: {
            Text("Is your headache gone? Tap Resolve to let the app know!")
          }
        }
        
        // Predictions
        if let prediction = predictor.prediction {
          let dailyOutlook = OutlookView(outlook: prediction.holisticOutlook)
          let severityPrediction = HorizontalSeverityLevel(currentSeverity: prediction.severityClassifierOutput.prediction, severityRange: nil, collapsed: true, action: nil)
          
          if currentHeadache == nil || debugShowAllViews {
            Section {
              dailyOutlook
            } header: {
              SectionTitleView(title: "Predictions")
            }
            
            Section {
              severityPrediction
            } footer: {
              if let lastPredictionDate = predictor.prediction?.date {
                Text("Updated at \(lastPredictionDate.formattedNonRelative()).")
              }
            }
          }
          else {
            Section {
              severityPrediction
            } header: {
              SectionTitleView(title: "Predictions")
            } footer: {
              if let lastPredictionDate = predictor.prediction?.date {
                Text("Updated \(lastPredictionDate.formattedNonRelative()).")
              }
            }
          }
        }
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("Track")
      .refreshable {
        predict(forced: true)
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
    .onAppear(perform: onAppear)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .confirmationDialog("Resolve Headache? It will be available in the Headaches tab.", isPresented: $showingResolveConfirmation, titleVisibility: .visible) {
      Button("Resolve", role: .destructive, action: resolve)
    }
  }
  
}

// MARK: Private methods

extension CurrentHeadacheView {
  
  /// Called when the app becomes active.
  private func didBecomeActive(_ notification: NotificationCenter.Publisher.Output) {
    logDebug("Did become active.")
    predict()
  }
  
  /// Called when the view appears and reloads the classifier input.
  private func onAppear() {
    guard !firstAppearance else {
      firstAppearance = false
      return
    }
    
    logDebug("On appear.")
    predict()
  }
  
  /// Updates the classifier input.
  private func predict(forced: Bool = false) {
    // Check if we should show the not-present training data cell
    headacheManager.needsNotPresentTrainingData { needsTrainingData in
      logDebug("Needs training data: \(needsTrainingData)")
      DispatchQueue.main.async {
        withAnimation {
          self.needsInput = needsTrainingData
        }
        
        // Check if we should run a prediction
        let now = Date()
        if let lastPredictionDate = predictor.prediction?.date {
          let timeSinceLastPrediction = now.timeIntervalSince(lastPredictionDate)
          guard forced || timeSinceLastPrediction > Constants.predictionRefreshInterval else {
            logDebug("Not updating prediction. Minimum interval, \(Constants.predictionRefreshInterval), not met with interval \(now.timeIntervalSince(lastPredictionDate)).")
            return
          }
        }
        
        logDebug("Predict.")
        
        // Run a prediction
        headacheManager.getCurrentClassifierInput { input, error in
          DispatchQueue.main.async {
            if let error = error {
              logError("Error getting classifier input: \(error)")
            }
            else if let input = input {
              do {
                _ = try withAnimation {
                  try predictor.predict(input)
                }
              }
              catch {
                logError("Error getting prediction: \(error)")
              }
            }
          }
        }
      }
    }
  }
  
  /// Displays the reset confirmation alert to the user.
  private func resolveConfirmation() {
    withAnimation { showingResolveConfirmation = true }
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
  
  /// Changes the current headache's severity or creates a new headache if one
  /// doesn't exist.
  ///
  /// - Parameter severity: The new severity.
  private func changeSeverity(to severity: HKCategoryValueSeverity) {
    guard !updatingHeadache else { return }
    logDebug("Change severity to \(severity.title).")
    
    updatingHeadache = true
    headacheManager.changeSeverity(to: severity) { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Update Severity", error)
        }
        
        updatingHeadache = false
      }
    }
  }
  
  /// Resolves the current headache.
  private func resolve() {
    guard !updatingHeadache else { return }
    logDebug("Resolve current headache.")
    
    updatingHeadache = true
    headacheManager.resolve { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Resolve Headache", error)
        }
        
        updatingHeadache = false
      }
    }
  }
  
  /// The action to perform if there is no headache.
  private func noHeadacheAction() {
    guard !handlingInput else { return }
    logDebug("No headache action.")
    
    handlingInput = true
    headacheManager.createTrainingData { _, error in
      if let error = error {
        handlingInput = false
        showAlert("Error Saving Data", error)
      }
      else {
        // Check if we should show the not-present training data cell
        headacheManager.needsNotPresentTrainingData { needsTrainingData in
          DispatchQueue.main.async {
            withAnimation {
              handlingInput = false
              needsInput = needsTrainingData
            }
          }
        }
      }
    }
  }
  
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    CurrentHeadacheView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.alertManager)
  }
}
