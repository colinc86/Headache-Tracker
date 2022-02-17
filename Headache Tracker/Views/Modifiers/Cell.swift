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
  
  /// The cell's footnote.
  var footnote: String? = nil
  
  /// The cell's foreground color.
  var foregroundColor: Color
  
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
        .padding([.top, .leading, .trailing])
        .padding(.bottom, 4)
        
        content
          .padding([.bottom, .leading, .trailing])
      }
      .background(Color(UIColor.secondarySystemGroupedBackground))
      .cornerRadius(12)
      
    
      if let footnote = footnote {
        Text(footnote)
          .font(.footnote)
          .foregroundColor(.secondary)
          .padding([.leading, .trailing])
      }
    }
    .padding([.leading, .trailing])
    .padding(.bottom, 10)
  }
}

extension View {
  func cell(title: String, footnote: String? = nil, systemImage: String, foregroundColor: Color = .accentColor) -> some View {
    modifier(
      Cell(systemImage: systemImage, title: title, footnote: footnote, foregroundColor: foregroundColor)
    )
  }
}
