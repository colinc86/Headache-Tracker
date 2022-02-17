//
//  SubtitleCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import SwiftUI

/// Displays a title with a subtitle in a cell.
struct SubtitleCell: View {
  
  // MARK: Public properties
  
  /// The cell's title.
  let title: String
  
  /// The cell's subtitle.
  let subtitle: String
  
  /// The system image name to use.
  var systemImage: String? = nil
  
  /// The color of the image.
  var imageForegroundColor: Color = .accentColor
  
  // MARK: View body
  
  var body: some View {
    HStack(alignment: .top) {
      if let systemImage = systemImage {
        Image(systemName: systemImage)
          .foregroundColor(imageForegroundColor)
      }
      Text(title)
      Spacer()
      Text(subtitle)
        .foregroundColor(.secondary)
    }
  }
}

struct SubtitleCell_Previews: PreviewProvider {
  static var previews: some View {
    SubtitleCell(title: "Title", subtitle: "Subtitle")
      .previewLayout(PreviewLayout.fixed(width: 428, height: 20))
  }
}
