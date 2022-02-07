//
//  SeverityLevel.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

struct SeverityLevel: View {
  
  @StateObject var headache: Headache
  
  var body: some View {
    VStack {
      ForEach(1 ..< 5) { i in
        if 5 - i < headache.severityRange.0.orderingValue ||
            5 - i > headache.severityRange.1.orderingValue {
          Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 10.0, height: 10.0)
        }
        else {
          Rectangle()
            .fill(color(for: 5 - i))
            .frame(width: 10.0, height: 10.0)
        }
        
        if i < 4 {
          Spacer()
        }
      }
    }
  }
}

extension SeverityLevel {
  
  func color(for index: Int) -> Color {
    switch index {
    case 1: return .cyan
    case 2: return .yellow
    case 3: return .orange
    case 4: return .red
    default: return .cyan
    }
  }
  
}

struct SeverityLevel_Previews: PreviewProvider {
  static var previews: some View {
    SeverityLevel(headache: Previewing.CoreData.headache)
  }
}
