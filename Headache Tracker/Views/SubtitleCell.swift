//
//  SubtitleCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/4/22.
//

import SwiftUI

struct SubtitleCell: View {
  let title: String
  let subtitle: String
  
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
