//
//  AnalyzeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct AnalyzeView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
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
      ScrollView(.vertical, showsIndicators: true) {
        
      }
      .navigationTitle("Analyze")
    }
  }
  
}

struct AnalyzeView_Previews: PreviewProvider {
  static var previews: some View {
    AnalyzeView()
  }
}
