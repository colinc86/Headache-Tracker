//
//  TagsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import Foundation
import SwiftUI

/// A view that displays an array of tags.
///
/// Set the style of the tags using the `.buttonStyle` modifier.
struct TagsView: View {
  
  /// The tags to display.
  let tags: [String]
  
  /// The action to call when a tag is tapped.
  let action: (String) -> Void
  
  // MARK: View body
  
  var body: some View {
    FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
      TagButton(tag, action: action)
    }
  }
  
}

struct TagsField_Previews: PreviewProvider {
  
  static var previews: some View {
    TagsView(tags: ["a", "test", "tag"]) { _ in }
      .buttonStyle(TagButtonStyle())
      .previewLayout(.sizeThatFits)
      .previewDisplayName("Normal tags")
    
    TagsView(tags: ["a", "test", "tag"]) { _ in }
      .buttonStyle(DeletableTagButtonStyle())
      .previewLayout(.sizeThatFits)
      .previewDisplayName("Deletable tags")
    
    TagsView(tags: ["lots", "of", "tags", "to", "test", "line", "breaks"]) { _ in }
      .buttonStyle(DeletableTagButtonStyle())
      .previewLayout(.sizeThatFits)
      .previewDisplayName("Multiline deletable tags")
  }
  
}
