//
//  TypeCardView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/24/22.
//

import SwiftUI

enum HeadacheType: RawRepresentable {
  
  typealias RawValue = String
  
  case cluster
  case migraine
  case sinus
  case tension
  case custom(type: String)
  
  var rawValue: String {
    switch self {
    case .cluster: return "cluster"
    case .migraine: return "migraine"
    case .sinus: return "sinus"
    case .tension: return "tension"
    case .custom(let type): return type
    }
  }
  
  init?(rawValue: RawValue) {
    if rawValue == Self.cluster.rawValue { self = .cluster }
    else if rawValue == Self.migraine.rawValue { self = .migraine }
    else if rawValue == Self.sinus.rawValue { self = .sinus }
    else if rawValue == Self.tension.rawValue { self = .tension }
    else { self = .custom(type: rawValue) }
  }
}

enum HeadacheClassification: String {
  case primary
  case secondary
}

struct TypeCardView: View {
  
  let type: HeadacheType
  let classification: HeadacheClassification
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
