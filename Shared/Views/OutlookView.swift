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
  
  private var caption: String? {
    switch outlook {
    case .noHeadache: return nil
    case .possibleHeadache(let onset): return "at " + onset.formattedTime()
    case .headache(_, let end): return "until " + end.formattedTime()
    }
  }
    
  var body: some View {
    TitleCaptionView(title: "Outlook", systemImage: "sun.and.horizon", foregroundColor: .mint, caption: caption) {
      Text(outlook.title)
        .font(.title)
    }
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
