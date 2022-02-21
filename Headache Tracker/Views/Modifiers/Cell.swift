//
//  Cell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct Cell: ViewModifier {
  
  // MARK: Public properties
  
  /// The cell's system image name.
  let systemImage: String
  
  /// The cell's title.
  let title: String
  
  /// The cell's foreground color.
  let foregroundColor: Color
  
  // MARK: Body content
  
  func body(content: Content) -> some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        HStack {
          Image(systemName: systemImage)
          Text(title)
          Spacer()
        }
        .foregroundColor(foregroundColor)
        .padding(.bottom, 8)
        
        content
      }
    }
    .frame(minWidth: 0, minHeight: 70)
    .padding([.top, .bottom], 10)
  }
}

extension View {
  func cell(title: String, systemImage: String, foregroundColor: Color = .accentColor) -> some View {
    modifier(
      Cell(systemImage: systemImage, title: title, foregroundColor: foregroundColor)
    )
  }
}
