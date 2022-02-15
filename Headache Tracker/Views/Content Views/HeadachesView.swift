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
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The headaches fetch request.
  /// Returns a list of all headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      List {
        ForEach(headaches) { headache in
          NavigationLink {
            HeadacheView(headache: headache)
              .environment(\.managedObjectContext, viewContext)
              .environmentObject(headacheManager)
          } label: {
            HeadacheCell(headache: headache)
          }
        }
        .onDelete(perform: deleteHeadaches)
      }
      .navigationTitle("Headaches")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
      }
    }
  }
  
}

// MARK: Private methods

extension HeadachesView {
  
  /// Deletes the items at the given offsets.
  ///
  /// - Parameter offsets: The item offsets.
  private func deleteHeadaches(offsets: IndexSet) {
    withAnimation {
      offsets.map { headaches[$0] }.forEach({ headacheManager.deleteHeadache(identifier: $0.identifier ?? UUID()) })
    }
  }
  
}

struct HeadachesView_Previews: PreviewProvider {
  static var previews: some View {
    HeadachesView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .onAppear {
        _ = Previewing.CoreData.headache
        _ = Previewing.CoreData.unresolvedHeadache
      }
  }
}
