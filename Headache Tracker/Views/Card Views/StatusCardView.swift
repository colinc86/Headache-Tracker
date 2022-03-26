//
//  StatusCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/4/22.
//

import SwiftUI

struct StatusCardView: View {
  
  /// The headache's resolution status.
  let resolved: Bool
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  var body: some View {
    TitleCaptionView(title: "Status", systemImage: "face.smiling.fill", foregroundColor: colorScheme.themeColor(for: .teal)) {
      Text(resolved ? "Resolved" : "Unresolved")
        .font(.title)
        .foregroundColor(colorScheme.themeColor(for: .teal))
    }
  }
  
}

struct StatusCardView_Previews: PreviewProvider {
  static var previews: some View {
    StatusCardView(resolved: true)
      .previewLayout(.fixed(width: 428, height: 70))
    
    StatusCardView(resolved: false)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
