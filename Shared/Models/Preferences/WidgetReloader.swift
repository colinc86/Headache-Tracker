//
//  WidgetReloader.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 9/30/26.
//

import Foundation
import WidgetKit

/// Requests widget timeline reloads by kind group, so every risk widget
/// refreshes together when the forecast or the current severity changes.
enum WidgetReloader {

  /// Reloads every widget that renders the risk forecast.
  static func reloadRisk() {
    for kind in Constants.Widgets.riskKinds {
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
  }

  /// Reloads the severity (quick-log) widget.
  static func reloadSeverity() {
    WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.severityWidgetKind)
  }

  /// Reloads every widget.
  static func reloadAll() {
    WidgetCenter.shared.reloadAllTimelines()
  }

}
