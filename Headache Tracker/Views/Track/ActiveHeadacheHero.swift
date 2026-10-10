//
//  ActiveHeadacheHero.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// The Track tab's hero during a headache: the orb in the current severity's
/// color with the elapsed time ticking inside it, the severity, and when it
/// began. The log bar below carries the actions.
struct ActiveHeadacheHero: View {

  /// The current severity.
  let severity: Headache.Severity

  /// When the headache began.
  let start: Date?

  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 60.0)) { context in
      VStack(spacing: Tokens.Spacing.md) {
        RiskOrb(percent: nil, tint: colorTheme.color(for: severity), diameter: 150, caption: start == nil ? nil : "so far", label: start.map({ Formatters.formatInterval(context.date.timeIntervalSince($0)) }))

        VStack(spacing: Tokens.Spacing.xs) {
          Text("\(severity.title) Headache")
            .font(.title3.weight(.semibold))
          if let start = start {
            Text("Started \(Formatters.formatTimeWithDay(start))")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          Text("Update the severity below as it changes, and resolve it when it's gone.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, Tokens.Spacing.xs)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Tokens.Spacing.md)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityText(at: context.date))
    }
  }

  private func accessibilityText(at date: Date) -> String {
    var text = "\(severity.title) headache"
    if let start = start {
      text += ", for \(Formatters.formatInterval(date.timeIntervalSince(start))), started \(Formatters.formatTimeWithDay(start))"
    }
    return text + "."
  }

}
