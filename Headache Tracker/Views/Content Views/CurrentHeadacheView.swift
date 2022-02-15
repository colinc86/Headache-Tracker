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
  
  /// The alert's title.
  @State private var alertTitle = ""
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  /// Whether or not the reset confirmation alert is visible.
  @State private var showingResetConfirmation = false
  
  /// True iff the current headache is being updated.
  @State private var updatingHeadache = false
  
  /// The classifier's current prediction.
  @State private var prediction: HeadachePredictor.Prediction?
  
  /// Whether or not the classifier input is being updated.
  @State private var predicting: Bool = false
  
  /// The last error produced by prediction.
  @State private var predictionError: Error? = nil
  
  /// Whether or not the headache manager needs more not-present headache training data.
  @State private var needsInput: Bool = false
  
  /// The current (unresolved) headache.
  private var currentHeadache: Headache? {
    return headaches.first
  }
  
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      Form {
        if let currentHeadache = currentHeadache {
          Section {
            SubtitleCell(title: "Severity", subtitle: currentHeadache.severity.title)
            SubtitleCell(title: "Last Updated", subtitle: currentHeadache.pendingEndTime?.formatted() ?? "N/A")
          }
        }
        
        Section {
          Button(HKCategoryValueSeverity.severe.title) { changeSeverity(to: .severe) }
          .disabled(currentHeadache?.severity == .severe)
          .disabled(updatingHeadache)
          
          Button(HKCategoryValueSeverity.moderate.title) { changeSeverity(to: .moderate) }
          .disabled(currentHeadache?.severity == .moderate)
          .disabled(updatingHeadache)
          
          Button(HKCategoryValueSeverity.mild.title) { changeSeverity(to: .mild) }
          .disabled(currentHeadache?.severity == .mild)
          .disabled(updatingHeadache)
          
          Button(HKCategoryValueSeverity.unspecified.title) { changeSeverity(to: .unspecified) }
          .disabled(currentHeadache?.severity == .unspecified)
          .disabled(updatingHeadache)
          
          Button(HKCategoryValueSeverity.notPresent.title) { changeSeverity(to: .notPresent) }
          .disabled(currentHeadache?.severity == .notPresent)
          .disabled(updatingHeadache)
        } footer: {
          if currentHeadache == nil {
            Text("Feel a headache coming on? Select a severity level to start tracking it.")
          }
        }
        
        if learnAndPredict && currentHeadache == nil && needsInput {
          Section {
            Button("No Headache", action: noHeadacheAction)
          }
        }
        else if currentHeadache != nil {
          Section {
            HStack {
              Spacer()
              Button("Resolve", action: resolve)
                .disabled(updatingHeadache)
              Spacer()
            }
            
            HStack {
              Spacer()
              Button("Reset", action: resetConfirmation)
                .disabled(updatingHeadache)
                .foregroundColor(.red)
              Spacer()
            }
          }
        }
        
        if learnAndPredict, let prediction = prediction {
          Section {
            SubtitleCell(title: "Boosted Tree", subtitle: prediction.boostedTreeOutput.title)
            SubtitleCell(title: "Decision Tree", subtitle: prediction.decisionTreeOutput.title)
            SubtitleCell(title: "Random Forest", subtitle: prediction.randomForestOutput.title)
            SubtitleCell(title: "Logistic Regression", subtitle: prediction.logisticRegressionOutput.title)
          }
        }
        else if let predictionError = predictionError {
          Section {
            HStack {
              Spacer()
              Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
              Spacer()
            }
            
            Text(predictionError.localizedDescription)
          }
        }
      }
      .navigationTitle("Current Headache")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if updatingHeadache || predicting {
            ProgressView()
              .progressViewStyle(DefaultProgressViewStyle())
          }
          else {
            EmptyView()
          }
        }
      }
    }
    .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
    .onAppear(perform: onAppear)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
    .destructiveConfirmationDialog(title: alertTitle, isPresented: $showingResetConfirmation, destructiveActionTitle: "Reset", destructiveAction: {
      reset()
      withAnimation { showingResetConfirmation = false }
    })
  }
  
}

// MARK: Private methods

extension CurrentHeadacheView {
  
  /// Called when the app becomes active.
  private func didBecomeActive(_ notification: NotificationCenter.Publisher.Output) {
    predict()
  }
  
  /// Called when the view appears and reloads the classifier input.
  private func onAppear() {
    predict()
  }
  
  /// Updates the classifier input.
  private func predict() {
    guard learnAndPredict else {
      predicting = false
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
    predicting = true
    headacheManager.getCurrentClassifierInput { input in
      DispatchQueue.main.async {
        if let input = input {
          do {
            prediction = try headachePredictor.predict(input)
          }
          catch {
            prediction = nil
            predictionError = error
          }
        }
        
        predicting = false
      }
    }
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
      }
    }
  }
  
  /// Resolves the current headache.
  private func resolve() {
    headacheManager.resolve { error in
      DispatchQueue.main.async {
        if let error = error {
          showAlert("Unable to Resolve Headache", error)
        }
      }
    }
  }
  
  /// Resets the current headache by deleting it.
  private func reset() {
    headacheManager.reset { error in
      if let error = error {
        DispatchQueue.main.async {
          showAlert("Unable to Reset Headache", error)
        }
      }
    }
  }
  
  /// The action to perform if there is no headache.
  private func noHeadacheAction() {
    headacheManager.trainClassifiers()
  }
  
  /// Displays the reset confirmation alert to the user.
  private func resetConfirmation() {
    if healthIntegration {
      showResetConfirmation("Are you sure you want to reset the headache and any associated Health app data?")
    }
    else {
      showResetConfirmation("Are you sure you want to reset the headache?")
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
