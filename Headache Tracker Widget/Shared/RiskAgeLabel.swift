//
//  RiskAgeLabel.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// How old the forecast is: "Updated 25m ago", dimmed while aging, and a
/// warning once stale. Nothing when there is no forecast.
struct RiskAgeLabel: View {

  /// The snapshot.
  let snapshot: RiskSnapshot

  /// The stale tint.
  var staleTint: Color = .orange

  var body: some View {
    if let age = snapshot.age, snapshot.freshness != .none {
      Group {
        switch snapshot.freshness {
        case .stale:
          Text("Stale · open to refresh")
            .foregroundStyle(staleTint)
        case .aging:
          Text("Updated \(RiskFormat.age(age))")
            .foregroundStyle(.tertiary)
        default:
          Text("Updated \(RiskFormat.age(age))")
            .foregroundStyle(.secondary)
        }
      }
      .font(.caption2)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
  }

}

/// A 6-point freshness dot: fresh, stale, or none. In tinted and vibrant
/// rendering a stale dot becomes an outlined circle so the state survives
/// without colour.
struct RiskAgeDot: View {

  /// The snapshot.
  let snapshot: RiskSnapshot

  /// The fresh tint.
  var freshTint: Color = .green

  /// The stale tint.
  var staleTint: Color = .orange

  /// The dot's diameter.
  var size: CGFloat = 6.0

  @Environment(\.widgetRenderingMode) private var renderingMode

  var body: some View {
    switch snapshot.freshness {
    case .none:
      Circle().fill(.quaternary).frame(width: size, height: size)
    case .stale:
      if renderingMode == .fullColor {
        Circle().fill(staleTint).frame(width: size, height: size)
      }
      else {
        Circle().stroke(Color.primary.opacity(0.5), lineWidth: 1.0).frame(width: size, height: size)
      }
    case .aging:
      Circle().fill(renderingMode == .fullColor ? freshTint.opacity(0.5) : Color.primary.opacity(0.5)).frame(width: size, height: size)
    case .fresh:
      Circle().fill(renderingMode == .fullColor ? freshTint : Color.primary).frame(width: size, height: size)
    }
  }

}
