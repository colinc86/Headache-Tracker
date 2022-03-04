//
//  StatusView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

struct StatusView: View {
  
  /// The headache's resolution status.
  let resolved: Bool
  
  var body: some View {
    TitleCaptionView(title: "Status", systemImage: "face.smiling.fill", foregroundColor: .teal) {
      Text(resolved ? "Resolved" : "Unresolved")
        .font(.title)
        .foregroundColor(.teal)
    }
  }
  
}

struct StatusView_Previews: PreviewProvider {
  static var previews: some View {
    StatusView(resolved: true)
      .previewLayout(.fixed(width: 428, height: 70))
    
    StatusView(resolved: false)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
