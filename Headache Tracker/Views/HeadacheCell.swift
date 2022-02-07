//
//  HeadacheCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

struct HeadacheCell: View {
  
  @StateObject var headache: Headache
  
  private let formatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.minute, .hour, .day]
    formatter.maximumUnitCount = 2
    return formatter
  }()
  
  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "brain.head.profile")
        .foregroundColor(headache.resolved ? .secondary : .accentColor)
      
      SeverityLevel(headache: headache)
      
      VStack {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formatted() ?? "N/A")
        SubtitleCell(title: "Duration", subtitle: formatter.string(from: headache.duration) ?? "0 minutes")
        SubtitleCell(title: "Severity", subtitle: headache.severityDescription)
      }
    }
  }
}

struct HeadacheCell_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheCell(headache: Previewing.CoreData.headache)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
}
