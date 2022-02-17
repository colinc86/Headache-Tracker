//
//  OnsetView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct OnsetView: View {
  
  /// The view's headache.
  @StateObject var headache: Headache
  
  var body: some View {
    Text(headache.severitiesArray.first?.startTime?.formatted() ?? "N/A")
      .font(.title)
  }
}

struct OnsetCell_Previews: PreviewProvider {
  static var previews: some View {
    OnsetView(headache: Previewing.CoreData.headache)
  }
}
