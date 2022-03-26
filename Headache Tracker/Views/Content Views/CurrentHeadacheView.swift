//
//  CurrentHeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI
import CoreData
import DataController

/// Shows and manages the current headache's UI.
struct CurrentHeadacheView: View {
  
  // MARK: Private properties
  
  /// The app's scene delegate.
  @EnvironmentObject private var sceneDelegate: SceneDelegate
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// The app's refresher.
  @EnvironmentObject private var refresher: Refresher
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// Whether the type view should be shown.
  @AppStorage(AppSettings.ListOptions.type) private var showTypeView = true
  
  /// Whether the onset view should be shown.
  @AppStorage(AppSettings.ListOptions.onset) private var showOnsetView = true
  
  /// Whether the duration view should be shown.
  @AppStorage(AppSettings.ListOptions.duration) private var showDurationView = true
  
  /// Whether the progression view should be shown.
  @AppStorage(AppSettings.ListOptions.progression) private var showProgressionView = true
  
  /// Whether the outlook view should be shown.
  @AppStorage(AppSettings.ListOptions.outlook) private var showOutlookView = true
  
  /// Whether the notes view should be shown.
  @AppStorage(AppSettings.ListOptions.notes) private var showNotesView = true
  
  /// Whether the tags view should be shown.
  @AppStorage(AppSettings.ListOptions.tags) private var showTagsView = true
  
  /// Whether the severity view should be shown.
  @AppStorage(AppSettings.ListOptions.severity) private var showSeverityView = true
  
  /// The Apple Health integration setting.
  @AppStorage(AppSettings.Health.healthIntegration) private var healthIntegration = false
    
  /// The headaches fetch request.
  /// Should only return one headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// Whether the change severity confirmation alert is visible.
  @State private var showingSeverityConfirmation = false
  
  /// Whether or not the headache manager needs more not-present headache training data.
  @State private var needsInput: Bool = false
  
  /// The application's first appearance.
  @State private var firstAppearance: Bool = true
  
  /// The identifier of the predection views.
  @State private var predictionID = UUID()
  
  /// The current (unresolved) headache.
  @MainActor private var currentHeadache: Headache? {
    return headaches.first
  }
  
  /// Called when the application becomes active.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  /// The waiter to automatically refresh the view.
  private let automaticRefreshWaiter = Waiter()
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        // New/Current Headache
        Section {
          // New/Current Severity
          SeveritySelectionView(currentSeverity: currentHeadache?.severity, action: changeSeverity)
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
            ActionCardView(title: "No Headache?", buttonTitle: "No Headache", systemImage: "checkmark.circle.fill", foregroundColor: .teal, action: noHeadacheAction)
          } footer: {
            Text("No Headache? Tap above to let the app know.")
          }
        }
        
        // Current Headache Information
        else if let currentHeadache = currentHeadache {
          HeadacheViews(headache: currentHeadache, allowsResolution: true, allowsEditing: false, allowsDeletion: false, showsAllCards: false)
            .id(currentHeadache)
        }
        
        // Predictions
        if let prediction = predictor.prediction {
          PredictionViews(prediction: prediction)
        }
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("Track")
      .animation(.default, value: predictor.prediction)
      .animation(.default, value: showTypeView)
      .animation(.default, value: showOnsetView)
      .animation(.default, value: showDurationView)
      .animation(.default, value: showProgressionView)
      .animation(.default, value: showNotesView)
      .animation(.default, value: showTagsView)
      .animation(.default, value: showOutlookView)
      .animation(.default, value: showSeverityView)
      .refreshable {
        do {
          try await predict(forced: true)
        }
        catch {
          logError("Error refreshing view: \(error)")
        }
      }
      .toolbar {
        ToolbarItem(placement: .automatic) {
          ListOptionsMenu()
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .onReceive(didBecomeActiveNotificationPublisher, perform: didBecomeActive)
    .onAppear(perform: onAppear)
    .onDisappear(perform: automaticRefreshWaiter.stop)
    .confirmationDialog("Change headache severity to \((sceneDelegate.desiredSeverity ?? .notPresent).title.lowercased())?", isPresented: $showingSeverityConfirmation, titleVisibility: .visible) {
      AsyncButton("Change", action: confirmChangeSeverity)
      Button("Cancel", role: .cancel, action: cancelChangeSeverity)
    }
  }
  
}

// MARK: Private methods

extension CurrentHeadacheView {
  
  /// Called when the app becomes active.
  private func didBecomeActive(_ notification: NotificationCenter.Publisher.Output) {
    // Were we launched from the widget?
    if sceneDelegate.desiredSeverity != nil {
      withAnimation {
        showingSeverityConfirmation = true
      }
    }
    
    // Run a prediction
    Task {
      do {
        try await predict()
      }
      catch {
        logError("Error predicting: \(error)")
      }
    }
  }
  
  /// Called when the view appears and reloads the classifier input.
  private func onAppear() {
    guard !firstAppearance else {
      firstAppearance = false
      return
    }
    
    // Run a prediction
    Task {
      do {
        try await predict()
      }
      catch {
        logError("Error predicting: \(error)")
      }
    }
  }
  
  /// Updates the classifier input.
  private func predict(forced: Bool = false) async throws {
    let needsData = try await headacheManager.needsTrainingData()
    
    await MainActor.run {
      withAnimation { needsInput = needsData }
    }
    
    // Check if we should run a prediction
    let now = Date()
    if let lastPredictionDate = predictor.prediction?.date {
      let timeSinceLastPrediction = now.timeIntervalSince(lastPredictionDate)
      guard forced || timeSinceLastPrediction > Constants.Tasks.predictionRefreshInterval else {
        logDebug("Not updating prediction. Minimum interval, \(Constants.Tasks.predictionRefreshInterval), not met with interval \(now.timeIntervalSince(lastPredictionDate)).")
        return
      }
    }
    
    logDebug("Updating current headache view prediction.")
    
    // Run a prediction
    try await headacheManager.createPredict(create: false, inWidget: false)
  }
  
  /// Changes the severity to the desired severity if available.
  private func confirmChangeSeverity() async throws {
    guard let severity = sceneDelegate.desiredSeverity else {
      return
    }
    
    // Reset the desired severity
    sceneDelegate.desiredSeverity = nil
    
    // Change the severity
    try await changeSeverity(to: severity)
  }
  
  /// Cancels the severity change.
  private func cancelChangeSeverity() {
    // Reset the desired severity
    sceneDelegate.desiredSeverity = nil
  }
  
  /// Changes the current headache's severity or creates a new headache if one
  /// doesn't exist.
  ///
  /// - Parameter severity: The new severity.
  private func changeSeverity(to severity: Headache.Severity) async throws {
    logDebug("Change severity to \(severity.title).")
        
    // Change the severity
    try await headacheManager.changeSeverity(to: severity)
    
    // Get the identifier
    let identifier = try await headacheManager.currentHeadacheIdentifier()
    try await self.refresher.presentCheckInAlert(with: identifier)
  }
  
  /// The action to perform if there is no headache.
  private func noHeadacheAction() async throws {
    logDebug("No headache action.")
    
    try await headacheManager.createPredict(inWidget: false)
    
    // Check if we should show the not-present training data cell
    let needsData = try await headacheManager.needsTrainingData()
    
    await MainActor.run {
      withAnimation { needsInput = needsData }
    }
  }
  
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    CurrentHeadacheView()
      .environmentObject(SceneDelegate())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .onAppear {
        Previewing.Prediction.predictor.prediction = .empty
      }
  }
}
