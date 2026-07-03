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
  
  // MARK: Types
  
  class ViewModel: ObservableObject {
    
    /// Whether the change severity confirmation alert is visible.
    @State var showingSeverityConfirmation = false
    
    /// Whether or not the headache manager needs more not-present headache training data.
    @State var needsInput: Bool = false
    
    /// The application's first appearance.
    @State var firstAppearance: Bool = true
    
    /// The identifier of the predection views.
    @State var predictionID = UUID()
    
    
    
    /// The waiter to automatically refresh the view.
    let automaticRefreshWaiter = Waiter()
    
    // MARK: Private properties
    
    /// The app's scene delegate.
    private let sceneDelegate: SceneDelegate
    
    /// The app's headache manager.
    private let headacheManager: HeadacheManager
    
    /// The app's headache predictor.
    private let predictor: Predictor
    
    /// The app's refresher.
    private let refresher: Refresher
    
    // MARK: Initializers
    
    init(sceneDelegate: SceneDelegate, headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
      self.sceneDelegate = sceneDelegate
      self.headacheManager = headacheManager
      self.predictor = predictor
      self.refresher = refresher
    }
    
  }
  
  // MARK: Private properties
  
  /// The app's scene delegate.
  @EnvironmentObject private var sceneDelegate: SceneDelegate
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// The view's model.
  @ObservedObject private var viewModel: ViewModel
  
  /// The headaches fetch request.
  ///
  /// It should ever only return at most one, unresolved, headache.
  @FetchRequest(
    sortDescriptors: [],
    predicate: NSPredicate(format: "resolved = false"),
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  /// The current (unresolved) headache.
  @MainActor private var currentHeadache: Headache? {
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
          SeveritySelectionView(currentSeverity: currentHeadache?.severity, action: viewModel.changeSeverity)
        } header: {
          SectionTitleView(title: currentHeadache == nil ? "New Headache" : "Current Headache")
        } footer: {
          if let currentHeadache = currentHeadache {
            if let startTime = currentHeadache.severitiesArray.last?.startTime {
              SectionFooterView(title: "Last updated \(startTime.formattedNonRelative())")
            }
          } else {
            SectionFooterView(title: "Feel a headache coming on? Select a severity level to start tracking it.")
          }
        }
        
        // No Headache
        if currentHeadache == nil && viewModel.needsInput {
          Section {
            ActionCard(title: "No Headache?", buttonTitle: "No Headache", systemImage: "checkmark.circle.fill", action: viewModel.noHeadacheAction)
          } footer: {
            SectionFooterView(title: "No Headache? Tap above to let the app know.")
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
      .refreshable(action: viewModel.forcedPrediction)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          ListOptionsMenu()
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .onReceive(didBecomeActiveNotificationPublisher, perform: viewModel.didBecomeActive)
    .onAppear(perform: viewModel.appeared)
    .onDisappear(perform: viewModel.automaticRefreshWaiter.stop)
    .confirmationDialog("Change headache severity to \((sceneDelegate.desiredSeverity ?? .notPresent).title.lowercased())?", isPresented: $viewModel.showingSeverityConfirmation, titleVisibility: .visible) {
      AsyncButton("Change", action: viewModel.confirmChangeSeverity)
      Button("Cancel", role: .cancel, action: viewModel.cancelChangeSeverity)
    }
  }
  
  init(sceneDelegate: SceneDelegate, headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
    viewModel = ViewModel(sceneDelegate: sceneDelegate, headacheManager: headacheManager, predictor: predictor, refresher: refresher)
  }
  
}

extension CurrentHeadacheView.ViewModel {
  
  @MainActor func setNeedsInput(_ needsInput: Bool) {
    withAnimation { self.needsInput = needsInput }
  }
  
  /// Called when the app becomes active.
  func didBecomeActive(_ notification: NotificationCenter.Publisher.Output) {
    // Were we launched from the widget?
    if sceneDelegate.desiredSeverity != nil {
      withAnimation {
        showingSeverityConfirmation = true
      }
    }
    
    // Run a prediction
    Task {
      await nonForcedPrediction()
    }
  }
  
  /// Called when the view appears and reloads the classifier input.
  func appeared() {
    guard !firstAppearance else {
      firstAppearance = false
      return
    }
    
    // Run a prediction
    Task {
      await nonForcedPrediction()
    }
  }
  
  @Sendable func forcedPrediction() async {
    do {
      try await predict(forced: true)
    }
    catch {
      logError("Error forced predicting: \(error)")
    }
  }
  
  func nonForcedPrediction() async {
    do {
      try await predict(forced: false)
    }
    catch {
      logError("Error predicting: \(error)")
    }
  }
  
  /// Updates the classifier input.
  func predict(forced: Bool = true) async throws {
    await setNeedsInput(try await headacheManager.needsTrainingData())
    
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
  
  /// Changes the current headache's severity or creates a new headache if one
  /// doesn't exist.
  ///
  /// - Parameter severity: The new severity.
  func changeSeverity(to severity: Headache.Severity) async throws {
    logDebug("Change severity to \(severity.title).")
    
    // Change the severity
    try await headacheManager.changeSeverity(to: severity)
    
    // Get the identifier
    let identifier = try await headacheManager.currentHeadacheIdentifier()
    try await self.refresher.presentCheckInAlert(with: identifier)
  }
  
  /// The action to perform if there is no headache.
  func noHeadacheAction() async throws {
    logDebug("No headache action.")
    
    try await headacheManager.createPredict(inWidget: false)
    
    // Check if we should show the not-present training data cell
    await setNeedsInput(try await headacheManager.needsTrainingData())
  }
  
  /// Changes the severity to the desired severity if available.
  @MainActor func confirmChangeSeverity() async throws {
    guard let severity = sceneDelegate.desiredSeverity else {
      return
    }
    
    // Reset the desired severity
    sceneDelegate.desiredSeverity = nil
    
    // Change the severity
    try await changeSeverity(to: severity)
  }
  
  /// Cancels the severity change.
  func cancelChangeSeverity() {
    // Reset the desired severity
    sceneDelegate.desiredSeverity = nil
  }
  
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static let refresher = Refresher()
  static var previews: some View {
    CurrentHeadacheView(sceneDelegate: SceneDelegate(), headacheManager: Previewing.headacheManager, predictor: Previewing.Prediction.predictor, refresher: refresher)
      .environmentObject(SceneDelegate())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(refresher)
      .onAppear {
        Previewing.Prediction.predictor.prediction = .empty
      }
  }
}
