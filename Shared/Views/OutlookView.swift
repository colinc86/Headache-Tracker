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
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  /// The caption to display.
  private var caption: String? {
    switch outlook {
    case .noHeadache: return nil
    case .possibleHeadache(let onset): return "at " + onset.formattedTime()
    case .headache(_, let end): return "until " + end.formattedTime()
    }
  }
  
  // MARK: View body
    
  var body: some View {
    Card(
      title: "Outlook",
      systemImage: "sun.and.horizon",
      foregroundColor: colorTheme.mint) {
      Text(outlook.title)
        .font(.title)
    } caption: {
      if let caption = caption {
        Text(caption)
      }
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
