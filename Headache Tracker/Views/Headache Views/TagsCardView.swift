//
//  TagsCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct TagsCardView: View {
  
  /// The card's tags.
  let tags: [String]
  
  /// Called when the edit button is tapped.
  let editAction: () -> Void
  
  /// Called when a tag is tapped.
  let tagAction: (String) -> Void
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: "Tags", systemImage: "tag", foregroundColor: .indigo, editButtonAction: editAction) {
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

struct TagsView_Previews: PreviewProvider {
  static var previews: some View {
    TagsCardView(tags: ["tag", "test", "values"], editAction: { }, tagAction: { _ in })
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .previewLayout(.fixed(width: 428, height: 70))
    
    TagsCardView(tags: [], editAction: { }, tagAction: { _ in })
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
