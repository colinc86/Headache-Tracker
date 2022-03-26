//
//  EditTypeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/25/22.
//

import SwiftUI

struct EditTypeView: View {
  
  /// The type to edit.
  @State var type: Headache.Types = .cluster
  
  /// The classification to edit.
  @State var classification: Headache.Classification = .primary
  
  /// The identifier of the headache to edit.
  @State var identifier: UUID = UUID()
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// Whether the view is being saved.
  @State private var saving: Bool = false
  
  /// The custom type value, if any.
  @State private var customTypeValue = ""
  
  /// The custom types to display to the user.
  private let customTypes: [Headache.Types] = SharedUserDefaults.standard.customTypes
  
  /// Whether saving is currently disabled.
  private var saveDisabled: Bool {
    if case .custom(_) = type, customTypeValue.isEmpty {
      return true
    }
    return false
  }
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      Form {
        Picker("Class", selection: $classification) {
          Text(Headache.Classification.primary.title).tag(Headache.Classification.primary)
          Text(Headache.Classification.secondary.title).tag(Headache.Classification.secondary)
        }
        .pickerStyle(InlinePickerStyle())
        
        Picker("Type", selection: $type) {
          ForEach(Headache.Types.definedCases) { type in
            Text(type.title).tag(type)
          }
        }
        .pickerStyle(InlinePickerStyle())
        
        Section {
          Picker("Custom Types", selection: $type) {
            ForEach(customTypes, id: \.self) { type in
              Text(type.title).tag(type)
            }
          }
          .pickerStyle(InlinePickerStyle())
          .labelsHidden()
          
          TextField("Custom Type", text: $customTypeValue, prompt: Text("Custom"))
        }
      }
      .navigationTitle("Type")
      .onChange(of: type, perform: changedType)
      .onChange(of: customTypeValue, perform: changedCustomTypeValue)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel, action: cancel)
            .disabled(saving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
          AsyncButton("Save", mode: .replacingContent, action: save)
            .disabled(saveDisabled)
        }
      }
    }
  }
  
}

// MARK: Private methods

extension EditTypeView {
  
  /// The cancel action.
  private func cancel() {
    dismiss()
  }
  
  /// Saves the headache.
  private func save() async throws {
    withAnimation {
      saving = true
    }
    
    // Update the headache
    try await headacheManager.updateHeadacheType(type, classification: classification, identifier: identifier)
    
    // Update the custom types
    try await headacheManager.updateCustomTypes()
    
    dismiss()
  }
  
  /// Dismisses the view.
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
  }
  
  /// Called when the type changes.
  ///
  /// - Parameter newValue: The new type.
  private func changedType(_ newValue: Headache.Types) {
    if Headache.Types.definedCases.contains(newValue) || customTypes.contains(newValue) {
      withAnimation {
        customTypeValue = ""
      }
    }
  }
  
  /// Called when the type value changes.
  ///
  /// - Parameter newValue: The new type value.
  private func changedCustomTypeValue(_ newValue: String) {
    let newValueType = Headache.Types(newValue)
    if !Headache.Types.definedCases.contains(newValueType) && !customTypes.contains(newValueType) {
      withAnimation { type = newValueType }
    }
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
