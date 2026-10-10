//
//  CardListRow.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// Lets a `Card` float cleanly as a list row, aligned with the system's own
/// cells: cancels the card's built-in gutter, zeroes the system horizontal
/// row inset, clears the opaque cell background, and hides the separator.
///
/// The negative padding matters. `Card` bakes in a `Tokens.Spacing.gutter`
/// margin (`Card.swift`) because it also renders *outside* a `List` — in the
/// widget — where that gutter is its only screen margin. Inside an
/// inset-grouped `List`, though, the section container already supplies a
/// ~20pt inset that `listRowInsets` does not remove, so the card's own gutter
/// stacked on top of it and left card backgrounds ~15pt narrower than the
/// plain system cells above them. Cancelling the gutter here puts the card
/// background flush with the section container, exactly where a system cell's
/// background sits, and leaves `Card`'s non-list uses untouched.
///
/// Apply to the card view that constitutes a `Section`'s row, e.g.
/// `Section { OnsetCard(onset: onset).cardListRow() }`. A row that omits it
/// simply keeps the default (double-inset) look — graceful degradation.
struct CardListRowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding([.leading, .trailing], -Tokens.Spacing.gutter)
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
