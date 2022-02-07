//
//  HeadachesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI

struct HeadachesView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    animation: .default)
  private var headaches: FetchedResults<Headache>
  
  var body: some View {
    NavigationView {
      List {
        ForEach(headaches) { headache in
          NavigationLink {
            HeadacheView(headache: headache)
              .environmentObject(headacheManager)
          } label: {
            HeadacheCell(headache: headache)
          }
        }
        .onDelete(perform: deleteItems)
      }
      .navigationTitle("Headaches")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
      }
    }
  }
  
  private func deleteItems(offsets: IndexSet) {
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
  }
}
