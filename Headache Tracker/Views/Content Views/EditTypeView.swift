//
//  EditTypeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/25/22.
//

import SwiftUI

struct EditTypeView: View {
  
  @State var type: Headache.Types = .cluster
  @State var classification: Headache.Classification = .primary
  @State var identifier: UUID = UUID()
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  @Environment(\.presentationMode) private var presentationMode
  @State private var saving: Bool = false
  
  /// The headaches fetch request.
  @FetchRequest(
    sortDescriptors: [],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  var customTypes: [Headache.Types] {
    var customTypes: [Headache.Types] = []
    for headache in headaches where !customTypes.contains(headache.headacheType) {
      guard case .custom(_) = headache.headacheType else { continue }
      customTypes.append(headache.headacheType)
    }
    return customTypes
  }
  
  var customTypeValue: Binding<String> {
    Binding<String> {
      if !customTypes.contains(type), case .custom(let rawValue) = type {
        return rawValue
      }
      return ""
    } set: { newValue in
      if case .custom(_) = type {
        type = .custom(type: newValue)
      }
    }

  }
  
  var body: some View {
    NavigationView {
      Form {
        Picker("Class", selection: $classification) {
          Text(Headache.Classification.primary.title).tag(Headache.Classification.primary)
          Text(Headache.Classification.secondary.title).tag(Headache.Classification.secondary)
        }
        .pickerStyle(InlinePickerStyle())
        
        Picker("Type", selection: $type) {
          Text(Headache.Types.cluster.title).tag(Headache.Types.cluster)
          Text(Headache.Types.migraine.title).tag(Headache.Types.migraine)
          Text(Headache.Types.tension.title).tag(Headache.Types.tension)
        }
        .pickerStyle(InlinePickerStyle())
        
        Section {
          Picker("Custom Types", selection: $type) {
            ForEach(customTypes, id: \.self) { type in
              Text(type.title).tag(type)
            }
            Text("Custom").tag(Headache.Types.custom(type: customTypeValue.wrappedValue))
          }
          .pickerStyle(InlinePickerStyle())
          .labelsHidden()
          
          if !customTypes.contains(.custom(type: customTypeValue.wrappedValue)) {
            TextField("Custom Type", text: customTypeValue, prompt: Text("Value"))
          }
        }
      }
      .navigationTitle("Type")
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

extension EditTypeView {
  
  private func cancel() {
    dismiss()
  }
  
  private func save() async throws {
    withAnimation {
      saving = true
    }
    
    try await headacheManager.updateHeadacheType(type, classification: classification, identifier: identifier)
    
    dismiss()
  }
  
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
  }
  
}

struct EditTypeView_Previews: PreviewProvider {
  static var previews: some View {
    EditTypeView(type: .cluster, classification: .primary, identifier: UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
    
    EditTypeView(type: .cluster, classification: .secondary, identifier: UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
    
    EditTypeView(type: .custom(type: "Test"), classification: .primary, identifier: UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
  }
}
