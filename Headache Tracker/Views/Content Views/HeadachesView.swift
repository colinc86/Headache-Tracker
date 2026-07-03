//
//  HeadachesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct HeadachesView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's alert manager.
  @EnvironmentObject private var alertManager: AlertManager
  
  /// The unresolveed headaches fetch request.
  /// Returns a list of all unresolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: false)),
    animation: .default)
  private var unresolvedHeadaches: FetchedResults<Headache>
  
  /// The resolveed headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: true)),
    animation: .default)
  private var resolvedHeadaches: FetchedResults<Headache>
  
  /// Whether the view is showing the add headache modal.
  @State private var showingAddHeadache: Bool = false
  
  // MARK: View body
  
  var body: some View {
    NavigationStack {
      List {
        if unresolvedHeadaches.count > 0 {
          Section {
            ForEach(unresolvedHeadaches) { headache in
              NavigationLink {
                HeadacheView(headache: headache)
              } label: {
                HeadacheCell(headache: headache)
              }
            }
          } header: {
            SectionTitleView(title: "Unresolved")
          }
        }
        
        if resolvedHeadaches.count > 0 {
          Section {
            ForEach(resolvedHeadaches) { headache in
              NavigationLink {
                HeadacheView(headache: headache)
              } label: {
                HeadacheCell(headache: headache)
              }
            }
          } header: {
            SectionTitleView(title: "Resolved")
          }
        }
      }
      .navigationTitle("Headaches")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button(action: addHeadache) {
            Label("Add", systemImage: "plus")
          }
        }
      }
    }
    .sheet(isPresented: $showingAddHeadache, onDismiss: nil) {
      NavigationStack {
        AddHeadacheView(headacheManager: headacheManager)
      }
    }
  }
  
}

// MARK: Private methods

extension HeadachesView {
  
  private func addHeadache() {
    withAnimation { showingAddHeadache = true }
  }
  
}

struct HeadachesView_Previews: PreviewProvider {
  static var previews: some View {
    HeadachesView()
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
