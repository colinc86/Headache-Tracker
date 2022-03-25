//
//  EditTagsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/22/22.
//

import SwiftUI

struct EditTagsView: View {
  
  @State var tags: [String]
  @State var identifier: UUID
  @State var newTag = ""
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  @Environment(\.presentationMode) private var presentationMode
  @State private var saving: Bool = false
  
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
  
  private func sanitizedTag(_ tag: String) -> String {
    tag
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
      .replacingOccurrences(of: " ", with: "-")
      .lowercased()
  }
  
  private func submitAction() {
    addTagAction(newTag)
  }
  
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
  
  private func deleteTagAction(_ tag: String) {
    withAnimation { tags.removeAll(where: { $0 == tag }) }
  }
  
  private func cancel() {
    dismiss()
  }
  
  private func save() async throws {
    withAnimation {
      saving = true
    }
    
    try await headacheManager.updateHeadacheTags(tags, identifier: identifier)
    
    dismiss()
  }
  
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
