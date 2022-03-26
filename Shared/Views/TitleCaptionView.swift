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
  var foregroundColor: Color
  
  /// The cell's optional caption.
  var caption: String? = nil
  
  /// The edit button's action.
  var editButtonAction: (() -> Void)? = nil
  
  /// the cell's content.
  var content: () -> Content
  
  // MARK: Body content
  
  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        HStack {
          HStack {
            Image(systemName: systemImage)
            Text(title)
          }
          .gradientForeground(colors: [foregroundColor.darker(by: 0.05), foregroundColor.lighter(by: 0.05)])
          
          Spacer()
          
          if let editButtonAction = editButtonAction {
            Button("Edit", action: editButtonAction)
              .buttonStyle(BorderlessButtonStyle())
          }
        }
        
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

struct TitleCaptionView_Previews: PreviewProvider {
  
  static var previews: some View {
    TitleCaptionView(title: "Test", systemImage: "clock", foregroundColor: .pink, caption: "Caption", editButtonAction: {
      
    }) {
      Text("Content")
    }
  }
  
}
