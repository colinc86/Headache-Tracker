//
//  TitleCaptionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct TitleCaptionView<Content: View>: View {
  
  // MARK: Public properties
  
  /// The cell's title.
  let title: String
  
  /// The cell's system image name.
  let systemImage: String
  
  /// The cell's foreground color.
  var foregroundColor: Color = .accentColor
  
  /// The cell's optional caption.
  var caption: String? = nil
  
  /// the cell's content.
  var content: () -> Content
  
  // MARK: Body content
  
  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        HStack {
          Image(systemName: systemImage)
          Text(title)
          Spacer()
        }
        .gradientForeground(colors: [foregroundColor.darker(by: 0.05), foregroundColor.lighter(by: 0.05)])
        .padding(.bottom, 8)
        
        content()
        
        if let caption = caption {
          Text(caption)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
    }
    .frame(minWidth: 0, minHeight: 70)
    .padding([.top, .bottom], 10)
  }
}
