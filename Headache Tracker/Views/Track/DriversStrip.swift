//
//  DriversStrip.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// What's moving today's forecast, as a row of chips under the hero: each
/// signal, today's value against the usual one, and how many points it adds
/// or takes away. Replaces the old "Why" card, which listed only the
/// above-usual signals as sentences.
struct DriversStrip: View {

  /// The drivers, strongest first.
  let drivers: [RiskDriver]

  /// Opens a driver.
  let onSelect: (RiskDriver) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
        ForEach(drivers) { driver in
          Button {
            onSelect(driver)
          } label: {
            DriverChip(driver: driver)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, Tokens.Spacing.gutter)
      .padding(.vertical, Tokens.Spacing.xxs)
    }
    .scrollClipDisabled()
  }

}

/// One driver.
struct DriverChip: View {

  let driver: RiskDriver

  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var color: Color {
    return driver.raising ? colorTheme.orange : colorTheme.green
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      HStack(spacing: 6) {
        Image(systemName: driver.systemImage)
          .font(.footnote.weight(.semibold))
          .foregroundColor(color)
        Text(driver.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
      }

      if let today = driver.todayText {
        Text(driver.usualText.map({ "\(today) · usual \($0)" }) ?? today)
          .font(.caption.monospacedDigit())
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      HStack(spacing: 3) {
        Image(systemName: driver.raising ? "arrow.up.right" : "arrow.down.right")
        Text(driver.deltaText.map({ "\($0) pts" }) ?? (driver.raising ? "Above usual" : "Below usual"))
          .monospacedDigit()
      }
      .font(.caption.weight(.semibold))
      .foregroundColor(color)
    }
    .padding(Tokens.Spacing.md)
    .frame(minWidth: 132, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: Tokens.Radius.lg)
        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground)))
    .overlay(
      RoundedRectangle(cornerRadius: Tokens.Radius.lg)
        .strokeBorder(color.opacity(0.35), lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilityText: String {
    var text = "\(driver.title), \(driver.raising ? "raising" : "easing") your risk"
    if let delta = driver.delta {
      text += " by \(Int((abs(delta) * 100.0).rounded())) points"
    }
    if let today = driver.todayText {
      text += ". Today \(today)"
      if let usual = driver.usualText {
        text += ", usually \(usual)"
      }
    }
    return text + "."
  }

}
