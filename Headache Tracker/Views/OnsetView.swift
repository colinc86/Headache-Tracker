//
//  OnsetView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct OnsetView: View {
  
  /// The view's onset.
  let onset: Date?
  
  var body: some View {
    if let onset = onset {
      Text(Calendar.current.relativeDateDescription(onset))
        .font(.title)
    }
  }
}

struct OnsetCell_Previews: PreviewProvider {
  static var previews: some View {
    OnsetView(onset: Previewing.CoreData.headache.startTime)
  }
}
