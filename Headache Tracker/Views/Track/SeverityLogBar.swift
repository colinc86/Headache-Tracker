//
//  SeverityLogBar.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// The Track tab's always-visible log bar, pinned above the tab bar. With no
/// headache: None plus every severity (Present, Mild, Moderate, Severe) to
/// start one in a tap. During a headache: the severities (the current one
/// selected) and Resolve.
struct SeverityLogBar: View {

  /// The current severity, nil with no headache.
  let currentSeverity: Headache.Severity?

  /// Logs a severity (starting or updating the headache).
  let onSeverity: (Headache.Severity) async throws -> Void

  /// Records "no headache right now".
  let onNoHeadache: () async throws -> Void

  /// Asks to resolve the headache.
  let onResolve: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// A brief "Logged" confirmation for the no-headache tap.
  @State private var loggedNoHeadache = false

  private static let severities: [Headache.Severity] = [.unspecified, .mild, .moderate, .severe]

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
      Text(currentSeverity == nil ? "Feel one coming on?" : "How is it now?")
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)

      HStack(spacing: Tokens.Spacing.xs) {
        if currentSeverity == nil {
          AsyncButton {
            try await onNoHeadache()
            withAnimation(Tokens.Motion.selection) { loggedNoHeadache = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(Tokens.Motion.selection) { loggedNoHeadache = false }
          } label: {
            pill(title: loggedNoHeadache ? "Logged" : "None", systemImage: loggedNoHeadache ? "checkmark" : "face.smiling", color: colorTheme.green, selected: loggedNoHeadache)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("No headache right now")
        }

        ForEach(SeverityLogBar.severities, id: \.rawValue) { severity in
          AsyncButton {
            try await onSeverity(severity)
          } label: {
            pill(title: severity.title, systemImage: nil, color: colorTheme.color(for: severity), selected: severity == currentSeverity)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(currentSeverity == nil ? "Start a \(severity.title.lowercased()) headache" : "\(severity.title) severity")
          .accessibilityAddTraits(severity == currentSeverity ? .isSelected : [])
        }

        if currentSeverity != nil {
          Button(action: onResolve) {
            pill(title: "Resolve", systemImage: "checkmark", color: colorTheme.teal, selected: true)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Resolve headache")
        }
      }
    }
    .padding(Tokens.Spacing.md)
    .background(
      RoundedRectangle(cornerRadius: Tokens.Radius.lg)
        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground)))
    .overlay(
      RoundedRectangle(cornerRadius: Tokens.Radius.lg)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    .padding(.horizontal, Tokens.Spacing.gutter)
    .padding(.top, Tokens.Spacing.xs)
    .padding(.bottom, Tokens.Spacing.sm)
    .sensoryFeedback(.selection, trigger: currentSeverity)
    .animation(Tokens.Motion.selection, value: currentSeverity)
  }

  private func pill(title: String, systemImage: String?, color: Color, selected: Bool) -> some View {
    VStack(spacing: 4) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .font(.footnote.weight(.bold))
          .frame(height: 12)
      }
      else {
        Circle()
          .fill(selected ? Color.white : color)
          .frame(width: 10, height: 10)
          .frame(height: 12)
      }
      Text(title)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .foregroundColor(selected ? .white : .primary)
    .frame(maxWidth: .infinity, minHeight: 52)
    .background(
      RoundedRectangle(cornerRadius: Tokens.Radius.md)
        .fill(selected ? color : color.opacity(0.16)))
    .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
  }

}
