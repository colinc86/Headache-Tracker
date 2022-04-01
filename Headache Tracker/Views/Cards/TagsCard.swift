//
//  TagsCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct TagsCard: View {
  
  /// The card's tags.
  let tags: [String]
  
  /// Called when the edit button is tapped.
  let editAction: () -> Void
  
  /// Called when a tag is tapped.
  let tagAction: (String) -> Void
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: "Tags",
      systemImage: "tag",
      foregroundColor: colorTheme.indigo
    ) {
      Button("Edit", action: editAction)
    } content: {
      ZStack(alignment: .leading) {
        TagsView(tags: tags, action: { _ in })
          .buttonStyle(TagButtonStyle())
        
        if tags.isEmpty {
          Text("Tap Edit to add tags.")
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

struct TagsCard_Previews: PreviewProvider {
  static var previews: some View {
    TagsCard(tags: ["tag", "test", "values"], editAction: { }, tagAction: { _ in })
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .previewLayout(.fixed(width: 428, height: 70))
    
    TagsCard(tags: [], editAction: { }, tagAction: { _ in })
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
