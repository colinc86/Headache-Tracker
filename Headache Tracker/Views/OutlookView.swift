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
    
  var body: some View {
    VStack(alignment: .leading) {
      Text(outlook.title)
        .font(.title)
      
      if outlook == .headache, let onset = onset {
        Text(onset.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
  }
  
  init(outlook: Outlook, onset: Date?) {
    self.outlook = outlook
    self.onset = onset
  }
  
}

struct OutlookView_Previews: PreviewProvider {
  static var previews: some View {
    OutlookView(outlook: .headache, onset: Date())
  }
}
