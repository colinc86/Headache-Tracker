//
//  EditableDateTimeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/14/22.
//

import SwiftUI

struct EditableDateTimeView: View {
  
  /// The view's onset.
  @Binding var onset: Date
  let title: String
  let systemImage: String
  let foregroundColor: Color
  
  var body: some View {
    TitleCaptionView(title: title, systemImage: systemImage, foregroundColor: foregroundColor) {
      DatePicker(selection: $onset, in: ...Date(), displayedComponents: [.date, .hourAndMinute]) {
        EmptyView()
      }
    }
  }
}

struct EditableDateTimeView_Previews: PreviewProvider {
  @State static var date = Date()
  static var previews: some View {
    EditableDateTimeView(onset: $date, title: "Onset", systemImage: "clock.fill", foregroundColor: .purple)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
