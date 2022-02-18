//
//  SeverityButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI
import HealthKit

struct SeverityButton: View {
  
  // MARK: Public properties
  
  /// The button's severity.
  let severity: HKCategoryValueSeverity
  
  /// The selected severity in the button's parent view.
  let selectedSeverity: HKCategoryValueSeverity?
  
  /// Whether or not the button should be drawn collapsed.
  let collapsed: Bool
  
  /// The button's action. If nil, then the button is drawn
  /// as a rectantle instead.
  let action: ((HKCategoryValueSeverity) -> Void)?
  
  // MARK: Private properties
  
  /// The dimensions of the button's rectangle.
  private let dimension: CGFloat = 60.0
  
  /// Whether or not this button is the selected button.
  private var selected: Bool {
    return severity == selectedSeverity
  }
  
  var body: some View {
    VStack {
      if let action = action {
        Button {
          action(severity)
        } label: {
          ZStack {
            RoundedRectangle(cornerRadius: 12)
              .frame(width: dimension, height: dimension)
              .foregroundColor(selected ? severity.uiColor : Color.secondary.opacity(0.25))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(severity.uiColor.opacity(0.25), lineWidth: 4.0)
              )
            
//            if let image = severity.image {
//              image
//                .resizable()
//                .frame(width: dimension, height: dimension, alignment: .center)
//                .foregroundColor(selected ? .primary : Color(UIColor.secondarySystemGroupedBackground))
//            }
          }
        }
        .buttonStyle(BorderlessButtonStyle())
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
        .foregroundColor(selectedSeverity == nil ? .primary : (selected ? .primary : .secondary))
    }
    
  }
  
}

struct SeverityButton_Previews: PreviewProvider {
  static var previews: some View {
    SeverityButton(severity: .notPresent, selectedSeverity: nil, collapsed: false) { _ in
      
    }
  }
}
