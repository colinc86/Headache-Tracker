//
//  HeadacheLiveActivity.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 7/3/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity shown while a headache is in progress.
struct HeadacheLiveActivity: Widget {

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: HeadacheActivityAttributes.self) { context in
      HeadacheActivityLockScreenView(context: context)
        .activityBackgroundTint(Color(uiColor: .systemBackground))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HeadacheActivitySeverityBadge(severity: context.state.severity)
            .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          Text(context.attributes.startDate, style: .relative)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 4)
        }

        DynamicIslandExpandedRegion(.bottom) {
          Button(intent: LogSeverityIntent(severity: .notPresent)) {
            Text("Resolve")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      } compactLeading: {
        Image(systemName: "brain.head.profile")
      } compactTrailing: {
        Text(context.attributes.startDate, style: .relative)
          .font(.caption2)
          .frame(maxWidth: 44)
      } minimal: {
        Image(systemName: "brain.head.profile")
      }
    }
  }

}

/// The activity's lock screen presentation.
struct HeadacheActivityLockScreenView: View {

  /// The activity context.
  let context: ActivityViewContext<HeadacheActivityAttributes>

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    HStack(spacing: 12) {
      HeadacheActivitySeverityBadge(severity: context.state.severity)

      VStack(alignment: .leading, spacing: 2) {
        Text("\(context.state.severity.title) Headache")
          .font(.headline)

        Text(context.attributes.startDate, style: .relative)
          .font(.caption)
          .foregroundColor(.secondary)

        if context.isStale {
          Text("Open the app to update")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      Button(intent: LogSeverityIntent(severity: .notPresent)) {
        Text("Resolve")
      }
      .buttonStyle(.bordered)
      .tint(colorTheme.baseColor)
    }
    .padding()
    .opacity(context.isStale ? 0.6 : 1.0)
  }

}

/// The colored severity capsule shared by the presentations.
struct HeadacheActivitySeverityBadge: View {

  /// The severity to display.
  let severity: Headache.Severity

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    Capsule()
      .fill(colorTheme.color(for: severity))
      .frame(width: 8, height: 44)
  }

}
