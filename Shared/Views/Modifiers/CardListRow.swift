//
//  CardListRow.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// Lets a `Card` float cleanly as a list row: zeroes the system horizontal
/// inset (so the card's own gutter is the only margin, de-doubling the
/// inset), clears the opaque cell background, and hides the separator.
///
/// Apply to the card view that constitutes a `Section`'s row, e.g.
/// `Section { OnsetCard(onset: onset).cardListRow() }`. A row that omits it
/// simply keeps the default (double-inset) look — graceful degradation.
struct CardListRowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .listRowInsets(EdgeInsets(
        top: Tokens.Spacing.xs,
        leading: 0,
        bottom: Tokens.Spacing.xs,
        trailing: 0))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}

extension View {

  /// Presents this card as a clean, edge-to-edge-margin list row.
  func cardListRow() -> some View {
    modifier(CardListRowModifier())
  }

}
