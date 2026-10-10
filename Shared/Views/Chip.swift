//
//  Chip.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// A capsule chip with selected / unselected / read-only variants — the
/// single chip vocabulary across tags and medication autocomplete.
/// Interactive only when given an `action`.
struct Chip: View {

  /// A chip's visual style.
  enum Style {
    case selected
    case unselected
    case readonly
  }

  /// The chip's title.
  let title: String

  /// An optional leading SF Symbol.
  var systemImage: String?

  /// The chip's style.
  var style: Style = .unselected

  /// The action to run on tap. Nil renders a non-interactive chip.
  var action: (() -> Void)?

  /// An accent replacing the theme's base color for the read-only style, so
  /// a chip can carry a semantic tint (a risk going down in green, say).
  var tint: Color?

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// Increments on each interactive tap to drive a selection haptic — the
  /// tactile half of the chip ritual (the spring is `Tokens.Motion.selection`).
  @State private var taps = 0

  // MARK: View body

  var body: some View {
    Group {
      if let action = action {
        Button {
          taps += 1
          action()
        } label: {
          label
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: taps)
      }
      else {
        label
      }
    }
    .animation(Tokens.Motion.selection, value: style)
    // Selection is otherwise conveyed only by fill color and a checkmark glyph,
    // which VoiceOver can't read as "selected" — mirror SeverityButton so a
    // chosen chip announces its state. (Read-only chips carry no selection.)
    .accessibilityAddTraits(style == .selected ? .isSelected : [])
  }

  // MARK: Private properties

  private var label: some View {
    HStack(spacing: Tokens.Spacing.xs) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .font(.caption)
      }
      Text(title)
        .font(.callout)
    }
    .padding(.horizontal, Tokens.Spacing.md)
    .padding(.vertical, Tokens.Spacing.sm - Tokens.Spacing.xxs)
    .background(Capsule().fill(fill))
    .foregroundColor(foreground)
  }

  private var fill: Color {
    switch style {
    case .selected: return colorTheme.baseColor
    case .unselected: return Color(UIColor.tertiarySystemFill)
    case .readonly: return (tint ?? colorTheme.baseColor).opacity(0.15)
    }
  }

  private var foreground: Color {
    switch style {
    case .selected: return Color(UIColor.systemBackground)
    case .unselected: return .primary
    case .readonly: return tint ?? colorTheme.baseColor
    }
  }

}

struct Chip_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 12) {
      Chip(title: "Caffeine", systemImage: "cup.and.saucer", style: .selected, action: {})
      Chip(title: "Alcohol", systemImage: "wineglass", style: .unselected, action: {})
      Chip(title: "Stress", systemImage: "bolt.heart", style: .readonly)
    }
    .padding()
    .previewLayout(.sizeThatFits)
  }
}
