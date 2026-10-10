//
//  EditTagsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct EditTagsView: View {
  
  /// The tags to edit.
  @State var tags: [String]
  
  /// The identifier of the headache to edit.
  @State var identifier: UUID
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.dismiss) private var dismiss
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// Whether the view is being saved.
  @State private var saving: Bool = false
  
  /// The new tag, if any.
  @State private var newTag = ""
  
  /// The tags fetch request.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(key: "value", ascending: true)],
    animation: .default)
  private var storedTags: FetchedResults<Tag>
  
  /// The tags to display below the add/search tag field.
  private var availableTags: [String] {
    let filteredTags = storedTags.filter({ !tags.contains($0.value ?? "") }).map({ $0.value ?? "" })
    let nonEmptyTags = filteredTags.filter({ !$0.isEmpty })
    
    if newTag.isEmpty {
      return nonEmptyTags
    }
    
    let sanitizedTag = sanitizedTag(newTag)
    if sanitizedTag.isEmpty {
      return nonEmptyTags
    }
    
    return nonEmptyTags.filter{( $0.contains(sanitizedTag) )}
  }
  
  /// The suggested tags.
  private var suggestedTags: [String] {
    let filteredTags = storedTags
      .filter({ !tags.contains($0.value ?? "") })
      // Tie-break by value so equally-used tags keep a stable order instead of
      // shuffling between opens — Swift's sort is unstable, and tag-count ties
      // are common (many tags are used just once).
      .sorted(by: { lhs, rhs in
        let lhsCount = lhs.headaches?.count ?? 0
        let rhsCount = rhs.headaches?.count ?? 0
        return lhsCount != rhsCount ? lhsCount > rhsCount : (lhs.value ?? "") < (rhs.value ?? "")
      })
      .map({ $0.value ?? "" })
    
    let nonEmptyTags = filteredTags.filter({ !$0.isEmpty })
    
    if nonEmptyTags.count < 5 {
      return nonEmptyTags
    }
    else {
      return [String](nonEmptyTags[0 ..< 5])
    }
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: newTag.isEmpty ? .center : .leading) {
          if !tags.isEmpty {
            TagsView(tags: tags, action: deleteTagAction)
              .buttonStyle(DeletableTagButtonStyle())
            Divider()
          }
          
          HStack {
            Image(systemName: "tag")
              .foregroundColor(Color(UIColor.tertiaryLabel))
            TextField("New Tag", text: $newTag, prompt: Text("Add or search for tags..."))
              .autocapitalization(.none)
              .submitLabel(.return)
              .onSubmit(submitAction)
          }
          .padding([.top, .bottom], Tokens.Spacing.xs)

          if newTag.isEmpty {
            Spacer(minLength: 50)
            // Suggested tags — wrapped as themed chips, matching the selected
            // tags above, instead of a vertical column of plain-text buttons.
            TagsView(tags: suggestedTags, action: addTagAction)
              .buttonStyle(TagButtonStyle())
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          else {
            TagsView(tags: availableTags, action: addTagAction)
              .buttonStyle(TagButtonStyle())
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding()
      .navigationTitle("Tags")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel, action: cancel)
            .disabled(saving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
          AsyncButton("Save", mode: .replacingContent, action: save)
        }
      }
    }
  }
  
}

// MARK: Private methods

extension EditTagsView {
  
  /// Sanitizes the tag by removing whitespace, pound-signs, and spaces.
  ///
  /// - Parameter tag: The tag to sanitize.
  /// - Returns: A string.
  private func sanitizedTag(_ tag: String) -> String {
    tag
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
      .replacingOccurrences(of: " ", with: "-")
      .lowercased()
  }
  
  /// Adds the tag.
  private func submitAction() {
    addTagAction(newTag)
  }
  
  /// Adds the given tag.
  ///
  /// - Parameter tag: The tag to add.
  private func addTagAction(_ tag: String) {
    let sanitizedTag = sanitizedTag(tag)
    
    guard !sanitizedTag.isEmpty else {
      return
    }
    
    guard !tags.contains(sanitizedTag) else {
      return
    }
    
    withAnimation {
      tags.append(sanitizedTag)
      newTag = ""
    }
  }
  
  /// Deletes the given tag.
  ///
  /// - Parameter tag: The tag to delete.
  private func deleteTagAction(_ tag: String) {
    withAnimation { tags.removeAll(where: { $0 == tag }) }
  }
  
  /// The cancel action.
  private func cancel() {
    dismiss()
  }
  
  /// Saves the headache.
  ///
  /// `@MainActor` so the `saving` state and `dismiss()` run on the main thread
  /// (`updateHeadacheTags` does its work off-main on a background context).
  @MainActor private func save() async throws {
    withAnimation {
      saving = true
    }
    // Reset on every exit. A failed save throws to the AsyncButton's alert
    // instead of dismissing, so without this the Cancel button would stay
    // stuck disabled and trap the user in the editor.
    defer { saving = false }

    try await headacheManager.updateHeadacheTags(tags, identifier: identifier)

    dismiss()
  }
  
}

struct EditTagsView_Previews: PreviewProvider {
  static var previews: some View {
    EditTagsView(tags: Previewing.CoreData.resolvedHeadache.tagsArray.map({ $0.value ?? "" }), identifier: Previewing.CoreData.resolvedHeadache.identifier ?? UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
