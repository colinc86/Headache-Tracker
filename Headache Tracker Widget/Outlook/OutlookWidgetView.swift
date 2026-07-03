//
//  OutlookWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/6/22.
//

import SwiftUI

struct OutlookWidgetView: View {

  /// The view's entry.
  let entry: OutlookWidgetContent

  /// What the widget should show.
  var outlook: RiskOutlook {
    if entry.hasCurrentHeadache {
      return .activeHeadache(severity: entry.currentSeverity ?? .unspecified, since: entry.headacheStart)
    }
    return .risk(entry.risk ?? .empty)
  }

  // MARK: View body

  var body: some View {
    if case .activeHeadache(_, .some(let start)) = outlook {
      // The relative text style self-updates, so a single timeline entry
      // keeps the elapsed time live.
      OutlookView(outlook: outlook)
        .overlay(alignment: .bottomTrailing) {
          Text(start, style: .relative)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(8)
        }
    }
    else {
      OutlookView(outlook: outlook)
    }
  }
}

struct OutlookWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookWidgetView(entry: OutlookWidgetProvider.placeholder)
  }
}
