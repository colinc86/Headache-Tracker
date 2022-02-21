//
//  Headache_Tracker_Widget.swift
//  Headache Tracker Widget
//
//  Created by Colin Campbell on 2/20/22.
//

import WidgetKit
import SwiftUI

let snapshotEntry = WidgetContent(outlook: .noHeadache, onset: nil)

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> WidgetContent {
    snapshotEntry
  }
  
  func getSnapshot(in context: Context, completion: @escaping (WidgetContent) -> ()) {
    let entry = snapshotEntry
    completion(entry)
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    var currentEntry: WidgetContent?
    if let date = SharedUserDefaults.standard.lastOutlookUpdate {
      currentEntry = WidgetContent(date: date, outlook: SharedUserDefaults.standard.outlook, onset: SharedUserDefaults.standard.onset)
    }
    
    let timeline = Timeline(entries: [currentEntry ?? snapshotEntry], policy: .atEnd)
    completion(timeline)
  }
}

struct OutlookEntryView: View {
  let entry: WidgetContent
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Image(systemName: "sun.and.horizon")
        Text("Outlook")
        Spacer()
      }
      .font(.headline)
      .foregroundColor(.mint)
      
      Text(entry.outlook.title)
        .font(.title)
      
      if let onset = entry.onset {
        Text(onset.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }
}

@main
struct Headache_Tracker_Widget: Widget {
  let kind: String = "Headache_Tracker_Widget"
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      OutlookEntryView(entry: entry)
    }
    .configurationDisplayName("Daily Outlook")
    .description("A daily headache outlook widget.")
    .supportedFamilies([.systemSmall])
  }
}

struct Headache_Tracker_Widget_Previews: PreviewProvider {
  static var previews: some View {
    OutlookEntryView(entry: snapshotEntry)
      .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
