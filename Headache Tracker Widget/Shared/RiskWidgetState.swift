//
//  RiskWidgetState.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The four states every risk widget renders.
enum RiskWidgetState {

  /// A live forecast.
  case forecast

  /// A forecast too old to trust.
  case stale

  /// A headache is in progress.
  case activeHeadache(RiskSnapshot.ActiveHeadache)

  /// No forecast yet.
  case empty

  init(_ snapshot: RiskSnapshot) {
    if let headache = snapshot.activeHeadache {
      self = .activeHeadache(headache)
    }
    else if snapshot.isEmpty {
      self = .empty
    }
    else if snapshot.isStale {
      self = .stale
    }
    else {
      self = .forecast
    }
  }

}

/// The empty state shared by every risk widget.
struct RiskEmptyStateView: View {

  /// Whether to draw the compact form (small and accessory families).
  var compact = false

  var body: some View {
    VStack(spacing: Tokens.Spacing.xs) {
      Image(systemName: "sparkles")
        .font(.system(size: compact ? 20 : 28, weight: .regular))
        .foregroundStyle(.secondary)
      Text("No forecast yet")
        .font(.system(compact ? .caption : .subheadline, design: .rounded).weight(.semibold))
      if !compact {
        Text("Log a few days to train your model")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("No forecast yet. Log a few days to train your model.")
  }

}

/// The active-headache badge: a severity-tinted capsule with the severity
/// word, the elapsed time (self-updating), and a tap hint.
struct ActiveHeadacheBadge: View {

  /// The headache.
  let headache: RiskSnapshot.ActiveHeadache

  /// The severity's tint.
  let tint: Color

  /// Whether to draw the compact form (small families).
  var compact = false

  /// Whether to show the tap hint.
  var showsHint = true

  @Environment(\.widgetRenderingMode) private var renderingMode

  private var title: String {
    return "\(headache.severity.title) Headache"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      Text(title)
        .font(.system(compact ? .subheadline : .headline, design: .rounded).weight(.semibold))
        .foregroundStyle(renderingMode == .fullColor ? tint : .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(Capsule().fill((renderingMode == .fullColor ? tint : Color.primary).opacity(0.18)))
        .widgetAccentable()

      if let start = headache.start {
        HStack(spacing: 3) {
          Text("for")
            .foregroundStyle(.secondary)
          Text(start, style: .relative)
            .monospacedDigit()
        }
        .font(.system(compact ? .subheadline : .title3, design: .rounded).weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      }

      if showsHint {
        Text("Tap to update")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .privacySensitive()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    if let start = headache.start {
      return "\(title), for \(RiskFormat.elapsed(since: start))."
    }
    return "\(title)."
  }

}
