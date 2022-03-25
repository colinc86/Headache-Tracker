//
//  TypeCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/24/22.
//

import SwiftUI

struct TypeCardView: View {
  
  let type: Headache.Types
  let classification: Headache.Classification
  var editButtonAction: (() -> Void)? = nil
  
  var body: some View {
    TitleCaptionView(title: "Type", systemImage: "slider.horizontal.below.square.filled.and.square", foregroundColor: .mint, caption: classification.rawValue.capitalized, editButtonAction: editButtonAction) {
      Text(type.rawValue.capitalized)
    }
  }
}

struct TypeCardView_Previews: PreviewProvider {
  static var previews: some View {
    TypeCardView(type: .cluster, classification: .primary)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
