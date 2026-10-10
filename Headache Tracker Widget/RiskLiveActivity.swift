//
//  RiskLiveActivity.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 7/18/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity shown during a high headache-risk window: a compact
/// gauge of the forecast probability and tier.
struct RiskLiveActivity: Widget {

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RiskActivityAttributes.self) { context in
      RiskActivityLockScreenView(context: context)
        .activityBackgroundTint(Color(uiColor: .systemBackground))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "brain.head.profile")
            .foregroundColor(RiskActivityStyle.tint(for: context.state.tier))
            .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          Text(RiskActivityStyle.percent(context.state.probability))
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundColor(RiskActivityStyle.tint(for: context.state.tier))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 4)
        }

        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.tier.title + " · next 24 hours")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } compactLeading: {
        Image(systemName: "brain.head.profile")
          .foregroundColor(RiskActivityStyle.tint(for: context.state.tier))
      } compactTrailing: {
        Text(RiskActivityStyle.percent(context.state.probability))
          .font(.caption2.weight(.semibold).monospacedDigit())
      } minimal: {
        Image(systemName: "brain.head.profile")
          .foregroundColor(RiskActivityStyle.tint(for: context.state.tier))
      }
    }
  }

}

/// Shared tint/format helpers so the presentations agree with the app's
/// tier→color mapping.
enum RiskActivityStyle {

  static func percent(_ probability: Double) -> String {
    return RiskFormat.percent(probability)
  }

  static func tint(for tier: RiskPrediction.RiskTier, theme: ColorTheme = Preferences.General().colorTheme) -> Color {
    return theme.color(for: tier)
  }

}

/// The activity's lock screen presentation.
struct RiskActivityLockScreenView: View {

  /// The activity context.
  let context: ActivityViewContext<RiskActivityAttributes>

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var tint: Color {
    RiskActivityStyle.tint(for: context.state.tier, theme: colorTheme)
  }

  var body: some View {
    HStack(spacing: 14) {
      // Gauge ring.
      ZStack {
        Circle()
          .stroke(tint.opacity(0.2), lineWidth: 6)
        Circle()
          .trim(from: 0, to: min(max(context.state.probability, 0), 1))
          .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text(RiskActivityStyle.percent(context.state.probability))
          .font(.caption.weight(.bold).monospacedDigit())
      }
      .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 2) {
        Text(context.state.tier.title)
          .font(.headline)
          .foregroundColor(tint)

        Text("Chance of a headache in the next 24 hours.")
          .font(.caption)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if context.isStale {
          Text("Open the app to refresh")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .opacity(context.isStale ? 0.6 : 1.0)
  }

}
