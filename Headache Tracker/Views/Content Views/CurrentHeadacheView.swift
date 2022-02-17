//
//  CurrentHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI
import SwiftUICharts
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
  
  /// The app's headache predictor.
  @EnvironmentObject private var headachePredictor: HeadachePredictor
  
  /// The app's alert manager for displaying notifications.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The Apple Health integration setting.
  @AppStorage(AppSettings.healthIntegration) private var healthIntegration = false
  
  /// The learn and predict setting.
  @AppStorage(AppSettings.learnAndPredict) private var learnAndPredict = false
    
  /// The headaches fetch request.
  /// Should only return one headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The validations fetch request.
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var validations: FetchedResults<ValidationData>
  
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
  
  /// The classifier's current prediction.
  @State private var prediction: HeadachePredictor.Prediction?
  
  /// The last error produced by prediction.
  @State private var predictionError: Error? = nil
  
  /// Whether or not the headache manager needs more not-present headache training data.
  @State private var needsInput: Bool = false
  
  @State private var boostedTreeHit: Bool = false
  @State private var boostedTreeAccuracy: Double = 0.0
  
  @State private var decisionTreeHit: Bool = false
  @State private var decisionTreeAccuracy: Double = 0.0
  
  @State private var randomForestHit: Bool = false
  @State private var randomForestAccuracy: Double = 0.0
  
  @State private var logisticRegressionHit: Bool = false
  @State private var logisticRegressionAccuracy: Double = 0.0
  
  /// The current (unresolved) headache.
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  /// Called when the application becomes active.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading) {
          // New/Current Headache Title
          SectionTitleView(title: currentHeadache == nil ? "New Headache" : "Current Headache")
          
          // New/Current Severity
          HorizontalSeverityLevel(currentSeverity: currentHeadache?.severity, collapsed: false, action: changeSeverity)
            .cell(
              title: "Severity",
              footnote: currentHeadache == nil ? "Feel a headache coming on? Select a severity level to start tracking it." : nil,
              systemImage: "brain.head.profile",
              foregroundColor: .cyan)
          
          // No Headache
          if learnAndPredict && currentHeadache == nil && needsInput {
            Button("No Headache", action: noHeadacheAction)
              .font(.title)
              .foregroundColor(.accentColor)
              .cell(title: "No Headache?", footnote: "No Headache? Tap above to let the app know.", systemImage: "checkmark.circle.fill", foregroundColor: .teal)
          }
          // Current Headache Information
          else if let currentHeadache = currentHeadache {
            // Onset
            OnsetView(headache: currentHeadache)
              .cell(title: "Onset", systemImage: "clock", foregroundColor: .purple)
            
            // Duration
            DurationView(headache: currentHeadache)
              .cell(title: "Duration", systemImage: "timer", foregroundColor: .green)
            
            // Progression
            if currentHeadache.severitiesArray.count > 1 {
              SeverityLineGraph(series: currentHeadache.severitySignal, gradient: Gradient(colors: currentHeadache.severityColorRange))
                .frame(height: 100)
                .cell(title: "Progression", systemImage: "chart.xyaxis.line", foregroundColor: .orange)
            }
            
            // Resolve the Headache
            Button("Resolve", action: resolveConfirmation)
              .font(.title)
              .foregroundColor(.accentColor)
              .cell(title: "Resolve Headache", systemImage: "face.smiling.fill", foregroundColor: .teal)
          }
          
          // Predictions
          if learnAndPredict, let prediction = prediction {
            SectionTitleView(title: "Predictions")
            
            VStack {
              HorizontalSeverityLevel(currentSeverity: prediction.boostedTreeOutput.severity, collapsed: true, action: nil)
              Divider().padding(0)
              SubtitleCell(title: "Probability", subtitle: String(format: "%0.f%%", prediction.boostedTreeOutput.probability * 100.0))
              Divider().padding(0)
              SubtitleCell(title: "Accuracy", subtitle: String(format: "%0.f%%", boostedTreeAccuracy * 100.0))
            }
            .cell(title: "Boosted Tree", systemImage: "chart.bar.xaxis", foregroundColor: .indigo)
            
            VStack {
              HorizontalSeverityLevel(currentSeverity: prediction.decisionTreeOutput.severity, collapsed: true, action: nil)
              Divider().padding(0)
              SubtitleCell(title: "Probability", subtitle: String(format: "%0.f%%", prediction.decisionTreeOutput.probability * 100.0))
              Divider().padding(0)
              SubtitleCell(title: "Accuracy", subtitle: String(format: "%0.f%%", decisionTreeAccuracy * 100.0))
            }
            .cell(title: "Decision Tree", systemImage: "chart.bar.xaxis", foregroundColor: .indigo)
            
            VStack {
              HorizontalSeverityLevel(currentSeverity: prediction.randomForestOutput.severity, collapsed: true, action: nil)
              Divider().padding(0)
              SubtitleCell(title: "Probability", subtitle: String(format: "%0.f%%", prediction.randomForestOutput.probability * 100.0))
              Divider().padding(0)
              SubtitleCell(title: "Accuracy", subtitle: String(format: "%0.f%%", randomForestAccuracy * 100.0))
            }
            .cell(title: "Random Forest", systemImage: "chart.bar.xaxis", foregroundColor: .indigo)
            
            VStack {
              HorizontalSeverityLevel(currentSeverity: prediction.logisticRegressionOutput.severity, collapsed: true, action: nil)
              Divider().padding(0)
              SubtitleCell(title: "Probability", subtitle: String(format: "%0.f%%", prediction.logisticRegressionOutput.probability * 100.0))
              Divider().padding(0)
              SubtitleCell(title: "Accuracy", subtitle: String(format: "%0.f%%", logisticRegressionAccuracy * 100.0))
            }
            .cell(title: "Logistic Regression", systemImage: "chart.bar.xaxis", foregroundColor: .indigo)
          }
        }
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("Track")
    }
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
    logDebug("On appear.")
    predict()
  }
  
  /// Updates the classifier input.
  private func predict() {
    logDebug("Predict.")
    guard learnAndPredict else {
      needsInput = false
      return
    }
    
    // Check if we should show the not-present training data cell
    headacheManager.needsNotPresentTrainingData { needsTrainingData in
      DispatchQueue.main.async {
        self.needsInput = needsTrainingData
      }
    }
    
    // Update the classifier input
    headacheManager.getCurrentClassifierInput { input, error in
      DispatchQueue.main.async {
        if let error = error {
          logError("Error getting classifier input: \(error)")
        }
        else if let input = input {
          do {
            try withAnimation {
              prediction = try headachePredictor.predict(input)
            }
          }
          catch {
            logError("Error getting prediction: \(error)")
            prediction = nil
          }
        }
      }
    }
    
    let boostedTreeHits = validations.reduce(0.0, { $0 + ($1.boostedTreeHit ? 1.0 : 0.0) })
    let decisionTreeHits = validations.reduce(0.0, { $0 + ($1.decisionTreeHit ? 1.0 : 0.0) })
    let randomForestHits = validations.reduce(0.0, { $0 + ($1.randomForestHit ? 1.0 : 0.0) })
    let logisticRegressionHits = validations.reduce(0.0, { $0 + ($1.logisticRegressionHit ? 1.0 : 0.0) })
    
    boostedTreeAccuracy = Double(boostedTreeHits) / Double(validations.count > 0 ? validations.count : 1)
    decisionTreeAccuracy = Double(decisionTreeHits) / Double(validations.count > 0 ? validations.count : 1)
    randomForestAccuracy = Double(randomForestHits) / Double(validations.count > 0 ? validations.count : 1)
    logisticRegressionAccuracy = Double(logisticRegressionHits) / Double(validations.count > 0 ? validations.count : 1)
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
    withAnimation {
      updatingHeadache = true
    }
    
    headacheManager.changeSeverity(to: severity) { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Update Severity", error)
        }
        
        withAnimation {
          updatingHeadache = false
        }
        
        DataController.shared.performInBackground { context in
          let validationData = ValidationData(context: context)
          validationData.boostedTreeHit = prediction?.boostedTreeOutput.severity == severity
          validationData.decisionTreeHit = prediction?.decisionTreeOutput.severity == severity
          validationData.randomForestHit = prediction?.randomForestOutput.severity == severity
          validationData.logisticRegressionHit = prediction?.logisticRegressionOutput.severity == severity
        }
      }
    }
  }
  
  /// Resolves the current headache.
  private func resolve() {
    logDebug("Resolve current headache.")
    headacheManager.resolve { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Resolve Headache", error)
        }
      }
    }
  }
  
  /// The action to perform if there is no headache.
  private func noHeadacheAction() {
    headacheManager.createTrainingData { error in
      if let error = error {
        showAlert("Error Saving Data", error)
      }
      else {
        // Check if we should show the not-present training data cell
        headacheManager.needsNotPresentTrainingData { needsTrainingData in
          DispatchQueue.main.async {
            self.needsInput = needsTrainingData
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
      .environmentObject(Previewing.headachePredictor)
      .environmentObject(Previewing.alertManager)
  }
}
