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
  
  // MARK: View body
  
  var body: some View {
    HStack(alignment: .top) {
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
  }
}
