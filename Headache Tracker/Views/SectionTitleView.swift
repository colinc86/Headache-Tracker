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
    Text(title)
      .font(.headline)
      .fontWeight(.heavy)
      .textCase(.none)
      .foregroundColor(.primary)
      .padding(.top, 0)
      .padding(.bottom, 4)
      .offset(x: -16)
  }
}

struct SectionTitleView_Previews: PreviewProvider {
  static var previews: some View {
    SectionTitleView(title: "Title")
      .previewLayout(.fixed(width: 428, height: 30))
  }
}
