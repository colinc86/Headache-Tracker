//
//  OutlookWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/1/22.
//

import WidgetKit
import SwiftUI

struct OutlookWidgetView: View {
  let entry: OutlookWidgetContent
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Image(systemName: "sun.and.horizon")
        Text("Outlook")
        Spacer()
      }
      .font(.headline)
      .foregroundColor(.mint)
      .padding(.bottom, 8)
      
      Text(entry.holisticOutlook.title)
        .font(.title)
      
      switch entry.holisticOutlook {
      case .noHeadache:
        EmptyView()
      case .possibleHeadache(let onset):
        Text("at " + onset.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      case .headache(_, let end):
        Text("until " + end.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }
}

struct OutlookWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookWidgetView(entry: OutlookWidgetProvider.placeholder)
      .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
