//
//  SeverityButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI
import HealthKit

struct SeverityButton: View {
  
  let severity: HKCategoryValueSeverity
  
  let selected: Bool
  
  let collapsed: Bool
  
  let action: ((HKCategoryValueSeverity) -> Void)?
  
  private let dimension: CGFloat = 60.0
  
  var body: some View {
    VStack {
      if let action = action {
        Button {
          action(severity)
        } label: {
          RoundedRectangle(cornerRadius: 12)
            .frame(width: dimension, height: dimension)
        }
        .foregroundColor(selected ? severity.uiColor : Color.secondary.opacity(0.25))
        .cornerRadius(12)
      }
      else {
        RoundedRectangle(cornerRadius: 12)
          .frame(width: dimension, height: collapsed ? 8.0 : dimension)
          .foregroundColor(selected ? severity.uiColor : Color.secondary.opacity(0.25))
      }
      
      Text(severity.title)
        .font(.caption)
        .foregroundColor(selected ? .primary : .secondary)
    }
    
  }
  
}

struct SeverityButton_Previews: PreviewProvider {
  static var previews: some View {
    SeverityButton(severity: .notPresent, selected: false, collapsed: false) { _ in
      
    }
  }
}
