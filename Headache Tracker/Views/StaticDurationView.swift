//
//  StaticDurationView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/18/22.
//

import SwiftUI

struct StaticDurationView: View {
  
  /// The view's onset.
  let duration: TimeInterval?
  
  var body: some View {
    if let duration = duration {
      Text(Formatters.dateComponentsFormatter.string(from: duration) ?? "N/A")
        .font(.title)
    }
  }
}

struct StaticDurationView_Previews: PreviewProvider {
  static var previews: some View {
    OnsetView(onset: Previewing.CoreData.headache.startTime)
  }
}

