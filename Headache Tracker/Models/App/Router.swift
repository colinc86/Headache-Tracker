//
//  Router.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import Foundation
import SwiftUI

/// Routes notification taps to the right tab and sheet.
class Router: ObservableObject {

  /// The app's tabs.
  enum Tab: Int {
    case track
    case profile
    case headaches
    case settings
  }

  /// A screen inside a tab that a deep link can land on.
  enum Destination: Equatable {
    case signals
    case insights
  }

  /// The selected tab.
  @Published var selectedTab = Tab.track

  /// A screen or section the Profile tab should show once it appears.
  @Published var pendingDestination: Destination?

  /// Routes to the Track tab.
  @MainActor func routeToTrack() {
    selectedTab = .track
  }

  /// Routes to the Profile tab, optionally onto a screen or section in it.
  ///
  /// - Parameter destination: Where to land.
  @MainActor func routeToProfile(_ destination: Destination? = nil) {
    selectedTab = .profile
    pendingDestination = destination
  }

}
