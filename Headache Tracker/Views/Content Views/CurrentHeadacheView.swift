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
    @Published var showingSeverityConfirmation = false

    /// Whether or not the headache manager needs more not-present headache training data.
    @Published var needsInput: Bool = false

    /// The application's first appearance.
    var firstAppearance: Bool = true

    /// The waiter to automatically refresh the view.
    let automaticRefreshWaiter = Waiter()

    // MARK: Private properties

    /// The app's headache manager.
    private let headacheManager: HeadacheManager

    /// The app's headache predictor.
    private let predictor: Predictor

    /// The app's refresher.
    private let refresher: Refresher

    // MARK: Initializers

    init(headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
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
  ///
  /// Held as a state object so parent re-renders don't recreate it (which
  /// reset its state and leaked refresh waiters when it was an observed
  /// object created in init).
  @StateObject private var viewModel: ViewModel
  
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

  /// Today's logged exposures (live).
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(key: "kindRaw", ascending: true)],
    predicate: NSPredicate(format: "timestamp >= %@", Calendar.current.startOfDay(for: Date()) as NSDate),
    animation: .default)
  private var todaysExposures: FetchedResults<Exposure>

  /// Whether the daily check-in sheet is visible.
  @State private var showingCheckInView = false

  /// The app's notification tap router.
  @EnvironmentObject private var router: Router

  /// Whether the check-in card should be shown.
  @AppStorage(Preferences.Lists.Keys.checkIn) private var showCheckInView = Preferences.Lists.Defaults.shown
  
  /// Called when the application becomes active.
  private let didBecomeActiveNotificationPublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
      List {
        // New/Current Headache
        Section {
          // New/Current Severity
          SeveritySelectionView(currentSeverity: currentHeadache?.severity, mode: .action(viewModel.changeSeverity))
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
        
        // Daily check-in
        if showCheckInView {
          Section {
            DailyCheckInCard(kinds: todaysExposures.compactMap({ $0.kindRaw })) {
              showingCheckInView = true
            }
          } footer: {
            SectionFooterView(title: "Logged exposures feed your correlation insights.")
          }
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
    .onReceive(didBecomeActiveNotificationPublisher) { _ in
      viewModel.didBecomeActive(hasDesiredSeverity: sceneDelegate.desiredSeverity != nil)
    }
    .onAppear(perform: viewModel.appeared)
    .sheet(isPresented: $showingCheckInView) {
      DailyCheckInView()
    }
    .onReceive(router.$pendingRoute) { route in
      guard case .dailyCheckIn = route else {
        return
      }
      router.pendingRoute = nil
      showingCheckInView = true
    }
    .onDisappear(perform: viewModel.automaticRefreshWaiter.stop)
    .confirmationDialog("Change headache severity to \((sceneDelegate.desiredSeverity ?? .notPresent).title.lowercased())?", isPresented: $viewModel.showingSeverityConfirmation, titleVisibility: .visible) {
      AsyncButton("Change") {
        // Read the desired severity from the live scene delegate; the view
        // model previously held a second instance that could disagree.
        let severity = sceneDelegate.desiredSeverity
        sceneDelegate.desiredSeverity = nil
        if let severity = severity {
          try await viewModel.changeSeverity(to: severity)
        }
      }
      Button("Cancel", role: .cancel) {
        sceneDelegate.desiredSeverity = nil
      }
    }
  }

  init(headacheManager: HeadacheManager, predictor: Predictor, refresher: Refresher) {
    _viewModel = StateObject(wrappedValue: ViewModel(headacheManager: headacheManager, predictor: predictor, refresher: refresher))
  }

}

extension CurrentHeadacheView.ViewModel {
  
  @MainActor func setNeedsInput(_ needsInput: Bool) {
    withAnimation { self.needsInput = needsInput }
  }
  
  /// Called when the app becomes active.
  ///
  /// - Parameter hasDesiredSeverity: Whether a widget deep link requested a
  ///   severity change.
  func didBecomeActive(hasDesiredSeverity: Bool) {
    // Were we launched from the widget?
    if hasDesiredSeverity {
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
    if let lastPredictionDate = predictor.prediction?.computedAt {
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
  
}

struct CurrentHeadacheView_Previews: PreviewProvider {
  static let refresher = Refresher()
  static var previews: some View {
    CurrentHeadacheView(headacheManager: Previewing.headacheManager, predictor: Previewing.Prediction.predictor, refresher: refresher)
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
