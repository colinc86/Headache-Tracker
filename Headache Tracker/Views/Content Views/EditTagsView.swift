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
  @Environment(\.presentationMode) private var presentationMode
  
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
      .sorted(by: { $0.headaches?.count ?? 0 > $1.headaches?.count ?? 0 })
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
    NavigationView {
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
          .padding([.top, .bottom], 4)
          
          if newTag.isEmpty {
            Spacer(minLength: 50)
            // Suggested tags
            ForEach(suggestedTags, id: \.self) { tag in
              TagButton(tag, action: addTagAction)
                .padding(4)
            }
          }
          else {
            ForEach(availableTags, id: \.self) { tag in
              TagButton(tag, action: addTagAction)
                .padding(4)
            }
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
  private func save() async throws {
    withAnimation {
      saving = true
    }
    
    try await headacheManager.updateHeadacheTags(tags, identifier: identifier)
    
    dismiss()
  }
  
  /// Dismisses the view.
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
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
