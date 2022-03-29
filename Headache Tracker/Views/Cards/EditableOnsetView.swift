//
//  EditableOnsetView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/14/22.
//

import SwiftUI

struct EditableDateTimeView: View {
  
  /// The view's onset.
  @Binding var onset: Date
  
  var body: some View {
    TitleCaptionView(title: "Onset", systemImage: "clock.fill", foregroundColor: .purple) {
      DatePicker(selection: $onset, displayedComponents: [.date, .hourAndMinute]) {
        EmptyView()
      }
    }
  }
}

struct EditableOnsetView_Previews: PreviewProvider {
  @State static var date = Date()
  static var previews: some View {
    EditableDateTimeView(onset: $date)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
