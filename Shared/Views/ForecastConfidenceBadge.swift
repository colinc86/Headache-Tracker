//
//  ForecastConfidenceBadge.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import SwiftUI

/// The forecast's confidence grade as a capsule badge, in the same style as
/// the Insights confidence badge so the two read as one vocabulary. Shared by
/// the app and the widgets; `monochrome` is for tinted and vibrant widget
/// rendering.
struct ForecastConfidenceBadge: View {

  /// The grade.
  let confidence: ForecastConfidence

  /// Whether to draw without colour.
  var monochrome = false

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var color: Color {
    return monochrome ? .primary : colorTheme.color(for: confidence)
  }

  var body: some View {
    Text(confidence.title)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(color.opacity(0.2)))
      .foregroundColor(color)
      .lineLimit(1)
      .fixedSize()
      .accessibilityLabel("Confidence: \(confidence.title)")
  }

}

#Preview {
  HStack {
    ForEach(ForecastConfidence.allCases, id: \.self) { confidence in
      ForecastConfidenceBadge(confidence: confidence)
    }
    ForecastConfidenceBadge(confidence: .steady, monochrome: true)
  }
  .padding()
}
