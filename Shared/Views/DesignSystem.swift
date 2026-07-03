//
//  DesignSystem.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// The app's design tokens: one spacing scale, one radius scale, one motion
/// vocabulary. Values are deliberately close to the pre-token literals so
/// adopting them is a *solidification*, not a redesign.
///
/// Caseless nested enums — no instances, zero runtime cost, and they
/// autocomplete as `Tokens.Spacing.md`.
enum Tokens {

  /// Spacing scale (points).
  enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    /// A card's interior padding.
    static let cardPadding: CGFloat = 15

    /// The horizontal margin from the screen edge to a card.
    static let gutter: CGFloat = 15

    /// A section footer's bottom padding.
    static let footerBottom: CGFloat = 30
  }

  /// Corner-radius scale (points). Capsules use `Capsule()`, not a radius.
  enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 15
  }

  /// Motion vocabulary.
  enum Motion {
    /// Selection feedback (severity buttons, chips): a small, quick spring.
    static let selection: Animation = .spring(response: 0.28, dampingFraction: 0.7)

    /// Content reveal (graph draw-on): deterministic, replacing the old
    /// per-appearance randomized durations.
    static let reveal: Animation = .easeInOut(duration: 0.4)
  }

  /// The canonical per-surface accent colors (read from the active theme).
  /// Documented here so new surfaces follow the established language rather
  /// than picking colors ad hoc:
  ///
  /// - severity picker → `cyan`
  /// - type → `mint`
  /// - onset → `purple`
  /// - duration → `green`
  /// - progression / daily check-in → `orange`
  /// - notes → `pink`
  /// - tags → `indigo`
  /// - status / medications / actions → `teal`
  /// - risk tiers → low `mint`, elevated `orange`, high `pink`
  enum Accent {}
}

// MARK: - Semantic color routing

extension ColorTheme {

  /// The accent color for a correlation insight's confidence. Routes
  /// through the theme so non-default themes (Grayscale, Monokai) stay
  /// coherent instead of clashing with hardcoded system greens/oranges.
  ///
  /// - Parameter confidence: The insight's confidence.
  /// - Returns: A theme-consistent color.
  func color(for confidence: TriggerInsight.Confidence) -> Color {
    switch confidence {
    case .strong: return green
    case .moderate: return orange
    case .suggestive: return .secondary
    }
  }

  /// The accent color for the "may be explained by…" confounder flag.
  var confounderFlag: Color {
    return orange
  }

}
