//
//  HorizontalSeverityLevelView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI
import HealthKit

/// Draws a horizontal severity level indicator.
struct HorizontalSeverityLevelView: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  let currentSeverity: HKCategoryValueSeverity?
  
  /// The headache's severity range to display.
  let severityRange: SeverityRange?
  
  /// The collapsed state of the view.
  let collapsed: Bool
  
  /// The action for each button.
  let action: ((HKCategoryValueSeverity) -> Void)?
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: "Severity", systemImage: "dial.max.fill", foregroundColor: .cyan) {
      HStack {
        Spacer(minLength: 0.0)
        HStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            SeverityButton(
              severity: severity(for: i),
              selectedSeverity: currentSeverity,
              selectedSeverityRange: severityRange,
              collapsed: collapsed,
              action: action)
            
            if i < 4 {
              Spacer(minLength: 0.0)
            }
          }
        }
        Spacer(minLength: 0.0)
      }
    }
  }
}

// MARK: Private methods

extension HorizontalSeverityLevelView {
  
  /// The severity for a given index.
  ///
  /// - Parameter index: The severity's index.
  /// - Returns: A severity.
  private func severity(for index: Int) -> HKCategoryValueSeverity {
    return HKCategoryValueSeverity(orderingValue: index) ?? .notPresent
  }
  
}

struct HorizontalSeverityLevelView_Previews: PreviewProvider {
  static var previews: some View {
    HorizontalSeverityLevelView(currentSeverity: nil, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevelView(currentSeverity: .mild, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevelView(currentSeverity: nil, severityRange: SeverityRange(lowerBound: .notPresent, upperBound: .severe), collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevelView(currentSeverity: nil, severityRange: nil, collapsed: true, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 70))
  }
}

struct SeverityButton: View {
  
  // MARK: Public properties
  
  /// The button's severity.
  let severity: HKCategoryValueSeverity
  
  /// The selected severity in the button's parent view.
  var selectedSeverity: HKCategoryValueSeverity? = nil
  
  /// The selected severity range in the button's parent view.
  var selectedSeverityRange: SeverityRange? = nil
  
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
    return (severity == selectedSeverity) || (selectedSeverityRange?.contains(severity) ?? false)
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
        .foregroundColor(selectedSeverity == nil && selectedSeverityRange == nil ? .primary : (selected ? .primary : .secondary))
    }
    
  }
  
}

struct SeverityButton_Previews: PreviewProvider {
  static var previews: some View {
    SeverityButton(severity: .notPresent, selectedSeverity: nil, collapsed: false, action: nil)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .unspecified, selectedSeverity: .unspecified, collapsed: false, action: nil)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .mild, selectedSeverity: nil, collapsed: true, action: nil)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .moderate, selectedSeverity: .moderate, collapsed: true, action: nil)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .severe, selectedSeverity: nil, collapsed: false, action: nil)
      .previewLayout(.fixed(width: 100, height: 100))
  }
}

