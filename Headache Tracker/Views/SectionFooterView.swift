//
//  SectionFooterView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 4/3/22.
//

import SwiftUI

struct SectionFooterView: View {
  
  /// The view's title.
  let title: String
  
  // MARK: View body
  
  var body: some View {
    HStack {
      Text(title)
        .font(.footnote)
        .textCase(.none)
        .foregroundColor(.secondary)
      Spacer()
    }
    // Horizontal gutter matches SectionTitleView so headers and footers share
    // a left edge; only the bottom uses the larger footer spacing.
    .padding([.leading, .trailing], Tokens.Spacing.gutter)
    .padding(.bottom, Tokens.Spacing.footerBottom)
  }
}

struct SectionFooterView_Previews: PreviewProvider {
  static var previews: some View {
    SectionFooterView(title: "This is a footnote.")
      .previewLayout(.sizeThatFits)
  }
}
