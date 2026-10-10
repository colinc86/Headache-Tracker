//
//  TrajectoryGlyph.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// A small arrow plus word for where the risk is heading. Hidden when the
/// trajectory is unknown.
struct TrajectoryGlyph: View {

  /// The trajectory.
  let trajectory: RiskSnapshot.Trajectory?

  /// The arrow's tint.
  let tint: Color

  /// Whether to show the word beside the arrow.
  var showsTitle = true

  var body: some View {
    if let trajectory = trajectory {
      HStack(spacing: 3) {
        Image(systemName: trajectory.systemImage)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(tint)
          .widgetAccentable()
        if showsTitle {
          Text(trajectory.title)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Risk \(trajectory.title.lowercased())")
    }
  }

}
