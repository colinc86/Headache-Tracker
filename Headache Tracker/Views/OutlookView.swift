//
//  OutlookView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import SwiftUI

struct OutlookView: View {
  
  /// The view's outlook.
  let outlook: HolisticOutlook
    
  var body: some View {
    VStack(alignment: .leading) {
      Text(outlook.title)
        .font(.title)
      
      switch outlook {
      case .noHeadache:
        EmptyView()
      case .possibleHeadache(let onset):
        Text("at " + onset.formattedTime())
          .font(.subheadline)
          .foregroundColor(.secondary)
      case .headache(_, let end):
        Text("until " + end.formattedTime())
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .cell(title: "Outlook", systemImage: "sun.and.horizon", foregroundColor: .mint)
  }
  
}

struct OutlookView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookView(outlook: .noHeadache)
      .previewLayout(.fixed(width: 428, height: 70))
    
    OutlookView(outlook: .possibleHeadache(onset: Date(timeIntervalSinceNow: 3600.0)))
      .previewLayout(.fixed(width: 428, height: 100))
    
    OutlookView(outlook: .headache(severity: .moderate, end: Date(timeIntervalSinceNow: 3600.0)))
      .previewLayout(.fixed(width: 428, height: 100))
  }
}
