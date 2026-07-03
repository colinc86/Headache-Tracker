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
    case analyze
    case headaches
    case settings
  }

  /// A destination beyond tab selection.
  enum Route {

    /// The daily exposure check-in sheet.
    case dailyCheckIn

  }

  /// The selected tab.
  @Published var selectedTab = Tab.track

  /// A pending route, consumed by the destination view.
  @Published var pendingRoute: Route?

  /// Routes to the Track tab, optionally with a pending destination.
  ///
  /// - Parameter route: The destination beyond the tab, if any.
  @MainActor func routeToTrack(_ route: Route? = nil) {
    selectedTab = .track
    pendingRoute = route
  }

}
