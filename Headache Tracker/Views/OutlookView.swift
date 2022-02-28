//
//  OutlookView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import SwiftUI

struct OutlookView: View {
  
  let outlook: Outlook
  
  let onset: Date?
  
  let duration: TimeInterval?
    
  var body: some View {
    VStack(alignment: .leading) {
      Text(outlook.rawValue)
        .font(.title)
      
      if outlook == .possibleHeadache, let onset = onset, onset.timeIntervalSince(Date()) > 0.0 {
        Text("at " + onset.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      else if outlook == .headache, let duration = duration {
        Text("until " + Date(timeIntervalSinceNow: duration).formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
  }
  
  init(outlook: Outlook, onset: Date?, duration: TimeInterval?) {
    self.outlook = outlook
    self.onset = onset
    self.duration = duration
  }
  
}

struct OutlookView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookView(outlook: .headache, onset: Date(), duration: 0.0)
  }
}
