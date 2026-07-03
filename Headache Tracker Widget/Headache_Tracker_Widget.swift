//
//  Headache_Tracker_Widget.swift
//  Headache Tracker Widget
//
//  Created by Colin Campbell on 2/20/22.
//

import WidgetKit
import SwiftUI

@main
struct HeadacheWidgets: WidgetBundle {
  var body: some Widget {
    OutlookWidget()
    SeverityWidget()
    HeadacheLiveActivity()
  }
}
