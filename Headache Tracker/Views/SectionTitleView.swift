//
//  SectionTitleView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct SectionTitleView: View {
  
  /// The view's title.
  let title: String
  
  // MARK: View body
  
  var body: some View {
    HStack {
      Text(title)
        .font(.headline)
        .textCase(.none)
        .foregroundColor(.primary)
      Spacer()
    }
    .padding([.leading, .trailing, .top], 15)
  }
}

struct SectionTitleView_Previews: PreviewProvider {
  static var previews: some View {
    SectionTitleView(title: "Title")
      .previewLayout(.sizeThatFits)
  }
}
