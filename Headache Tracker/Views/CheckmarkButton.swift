//
//  CheckmarkButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct CheckmarkButton: View {
  
  let title: String
  @Binding var checked: Bool
  
  var body: some View {
    Button {
      withAnimation { checked.toggle() }
    } label: {
      if checked {
        Label(title, systemImage: "checkmark")
      }
      else {
        Text(title)
      }
    }
  }
}

struct CheckmarkButton_Previews: PreviewProvider {
  static var previews: some View {
    CheckmarkButton(title: "Test", checked: Previewing.$booleanTrueValue)
      .previewLayout(.sizeThatFits)
    
    CheckmarkButton(title: "Test", checked: Previewing.$booleanFalseValue)
      .previewLayout(.sizeThatFits)
  }
}
