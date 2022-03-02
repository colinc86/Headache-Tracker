//
//  SeverityWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 3/2/22.
//

import HealthKit
import WidgetKit
import SwiftUI

struct SeverityWidgetView: View {
  let entry: SeverityWidgetContent
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Image(systemName: "dial.max.fill")
        Text("Severity")
        Spacer()
      }
      .font(.headline)
      .foregroundColor(.cyan)
      .padding(.bottom, 8)
      
      HStack {
        Spacer(minLength: 0.0)
        HStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            SeverityButton(severity: HKCategoryValueSeverity(orderingValue: i) ?? .notPresent, selectedSeverity: entry.severity)
            
            if i < 4 {
              Spacer(minLength: 0.0)
            }
          }
        }
        Spacer(minLength: 0.0)
      }
    }
    .padding()
  }
}

struct SeverityWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    SeverityWidgetView(entry: SeverityWidgetProvider.placeholder)
      .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}

struct SeverityButton: View {
  
  // MARK: Public properties
  
  /// The button's severity.
  let severity: HKCategoryValueSeverity
  
  /// The selected severity in the button's parent view.
  var selectedSeverity: HKCategoryValueSeverity? = nil
  
  // MARK: Private properties
  
  /// The dimensions of the button's rectangle.
  private let dimension: CGFloat = 60.0
  
  /// Whether or not this button is the selected button.
  private var selected: Bool {
    return severity == selectedSeverity
  }
  
  private var destinationURL: URL {
    return URL(string: "myheadache://severity?rawValue=\(severity.rawValue)")!
  }
  
  var body: some View {
    VStack {
      Link(destination: destinationURL) {
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .frame(width: dimension, height: dimension)
            .foregroundColor(selected ? severity.uiColor : Color.secondary.opacity(0.25))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(severity.uiColor.opacity(0.25), lineWidth: 4.0)
            )
        }
      }
      .buttonStyle(BorderlessButtonStyle())
      .foregroundColor(selected ? severity.uiColor : Color.secondary.opacity(0.25))
      .cornerRadius(12)
      
      Text(severity.title)
        .font(.caption)
        .foregroundColor(selectedSeverity == nil ? .primary : (selected ? .primary : .secondary))
    }
    
  }
  
}

struct SeverityButton_Previews: PreviewProvider {
  static var previews: some View {
    SeverityButton(severity: .notPresent, selectedSeverity: nil)
  }
}

fileprivate extension HKCategoryValueSeverity {
  
  /// The severity's title suitable for a user.
  var title: String {
    switch self {
    case .notPresent: return "Not Present"
    case .mild: return "Mild"
    case .moderate: return "Moderate"
    case .severe: return "Severe"
    case .unspecified: return "Present"
    default: return "Unknown"
    }
  }
  
  /// The color to use when drawing the value in the user interface.
  var uiColor: Color {
    switch self {
    case .notPresent: return .cyan
    case .unspecified: return .mint
    case .mild: return .yellow
    case .moderate: return .orange
    case .severe: return .red
    default: return .cyan
    }
  }
  
  /// The value's integer value representation.
  var orderingValue: Int {
    switch self {
    case .notPresent: return 0
    case .unspecified: return 1
    case .mild: return 2
    case .moderate: return 3
    case .severe: return 4
    default: return -1
    }
  }
  
  init?(orderingValue: Int) {
    switch orderingValue {
    case 0: self = .notPresent
    case 1: self = .unspecified
    case 2: self = .mild
    case 3: self = .moderate
    case 4: self = .severe
    default: return nil
    }
  }
  
  init?(title: String) {
    switch title {
    case HKCategoryValueSeverity.notPresent.title: self = .notPresent
    case HKCategoryValueSeverity.unspecified.title: self = .unspecified
    case HKCategoryValueSeverity.mild.title: self = .mild
    case HKCategoryValueSeverity.moderate.title: self = .moderate
    case HKCategoryValueSeverity.severe.title: self = .severe
    default: return nil
    }
  }
  
}
