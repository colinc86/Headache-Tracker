//
//  EditableDateTimeCard.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/14/22.
//

import SwiftUI

struct EditableDateTimeCard: View {
  
  /// The card's title.
  let title: String
  
  /// The card's foreground color.
  let foregroundColor: Color
  
  /// The view's date to edit.
  @Binding var date: Date
  
  // MARK: View body
  
  var body: some View {
    Card(
      title: title,
      systemImage: "clock",
      foregroundColor: foregroundColor
    ) {
      DatePicker(selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute]) {
        EmptyView()
      }
    }
  }
}

struct EditableDateTimeCard_Previews: PreviewProvider {
  @State static var date = Date()
  static var previews: some View {
    EditableDateTimeCard(title: "Onset", foregroundColor: .purple, date: $date)
      .previewLayout(.fixed(width: 428, height: 70))
  }
}
