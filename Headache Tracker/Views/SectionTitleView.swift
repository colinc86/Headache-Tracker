//
//  SectionTitleView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

struct SectionTitleView: View {
  
  let title: String
  
  var body: some View {
    HStack {
      Text(title)
        .font(.headline)
      Spacer()
    }
    .padding([.leading, .trailing, .top])
    .padding(.bottom, 10)
  }
}

struct SectionTitleView_Previews: PreviewProvider {
  static var previews: some View {
    SectionTitleView(title: "Title")
  }
}
