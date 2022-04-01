//
//  TypeCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/24/22.
//

import SwiftUI

struct TypeCard: View {
  
  /// The headache type.
  let type: Headache.Types
  
  /// The headache classification.
  let classification: Headache.Classification
  
  /// The action to perform when the edit button is tapped.
  let editAction: () -> Void
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Type",
      systemImage: "slider.horizontal.below.square.filled.and.square",
      foregroundColor: colorTheme.mint
    ) {
      Button("Edit", action: editAction)
    } content: {
      Text(type.rawValue.capitalized)
    } caption: {
      Text(classification.rawValue.capitalized)
    }
  }
}

struct TypeCard_Previews: PreviewProvider {
  static var previews: some View {
    TypeCard(type: .cluster, classification: .primary, editAction: {})
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
