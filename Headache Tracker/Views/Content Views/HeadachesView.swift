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
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
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
            .onDelete(perform: deleteUnresolvedHeadaches)
          } header: {
            SectionTitleView(title: "Unresolved")
          }
        }
        
        Section {
          ForEach(resolvedHeadaches) { headache in
            NavigationLink {
              HeadacheView(headache: headache)
            } label: {
              HeadacheCell(headache: headache)
            }
          }
          .onDelete(perform: deleteResolvedHeadaches)
        } header: {
          SectionTitleView(title: "Resolved")
        }
      }
      .navigationTitle("Headaches")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
  
}

// MARK: Private methods

extension HeadachesView {
  
  /// Deletes the items at the given offsets.
  ///
  /// - Parameter offsets: The item offsets.
  private func deleteUnresolvedHeadaches(offsets: IndexSet) {
    withAnimation {
      offsets.map { unresolvedHeadaches[$0] }.forEach({ headacheManager.deleteHeadache(identifier: $0.identifier ?? UUID()) })
    }
  }
  
  /// Deletes the items at the given offsets.
  ///
  /// - Parameter offsets: The item offsets.
  private func deleteResolvedHeadaches(offsets: IndexSet) {
    withAnimation {
      offsets.map { resolvedHeadaches[$0] }.forEach({ headacheManager.deleteHeadache(identifier: $0.identifier ?? UUID()) })
    }
  }
  
}

struct HeadachesView_Previews: PreviewProvider {
  static var previews: some View {
    HeadachesView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
