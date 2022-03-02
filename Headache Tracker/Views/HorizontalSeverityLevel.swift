//
//  HorizontalSeverityLevel.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI
import HealthKit

/// Draws a horizontal severity level indicator.
struct HorizontalSeverityLevel: View {
  
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
    .cell(title: "Severity", systemImage: "dial.max.fill", foregroundColor: .cyan)
  }
}

// MARK: Private methods

extension HorizontalSeverityLevel {
  
  /// The severity for a given index.
  ///
  /// - Parameter index: The severity's index.
  /// - Returns: A severity.
  private func severity(for index: Int) -> HKCategoryValueSeverity {
    return HKCategoryValueSeverity(orderingValue: index) ?? .notPresent
  }
  
}

struct HorizontalSeverityLevel_Previews: PreviewProvider {
  static var previews: some View {
    HorizontalSeverityLevel(currentSeverity: nil, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevel(currentSeverity: .mild, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevel(currentSeverity: nil, severityRange: SeverityRange(lowerBound: .notPresent, upperBound: .severe), collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    HorizontalSeverityLevel(currentSeverity: nil, severityRange: nil, collapsed: true, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 70))
  }
}

