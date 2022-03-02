//
//  OnsetView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct OnsetView: View {
  
  /// The view's onset.
  let onset: Date
  
  /// Whether the title should be printed as a relative date.
  var relativeDate: Bool = true
  
  var body: some View {
    Text(relativeDate ? onset.formattedRelative() : onset.formattedNonRelative())
      .font(.title)
      .cell(title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
  }
}

struct OnsetCell_Previews: PreviewProvider {
  static var previews: some View {
    OnsetView(onset: Date(timeIntervalSinceNow: -3600.0))
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
