//
//  SeveritySelectionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

/// Draws a horizontal severity level indicator.
struct SeveritySelectionView: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  let currentSeverity: Headache.Severity?
  
  /// The headache's severity range to display.
  var severityRange: Headache.Severity.Range? = nil
  
  /// The collapsed state of the view.
  var collapsed: Bool = false
  
  /// Whether the view should represent links.
  var link: Bool = false
  
  /// The action for each button.
  var action: ((Headache.Severity) async throws -> Void)? = nil
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  // MARK: View body
  
  var body: some View {
    TitleCaptionView(title: "Severity", systemImage: "dial.max.fill", foregroundColor: colorScheme.themeColor(for: .cyan)) {
      HStack {
        Spacer(minLength: 0.0)
        HStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            SeverityButton(
              severity: severity(for: i),
              selectedSeverity: currentSeverity,
              selectedSeverityRange: severityRange,
              collapsed: collapsed,
              link: link,
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

extension SeveritySelectionView {
  
  /// The severity for a given index.
  ///
  /// - Parameter index: The severity's index.
  /// - Returns: A severity.
  private func severity(for index: Int) -> Headache.Severity {
    return Headache.Severity(orderingValue: index) ?? .notPresent
  }
  
}

struct SeveritySelectionView_Previews: PreviewProvider {
  static var previews: some View {
    SeveritySelectionView(currentSeverity: nil, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: .mild, severityRange: nil, collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: nil, severityRange: Headache.Severity.Range(uncheckedBounds: (.notPresent, .severe)), collapsed: false, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: nil, severityRange: nil, collapsed: true, action: nil)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 70))
  }
}

struct SeverityButton: View {
  
  // MARK: Public properties
  
  /// The button's severity.
  let severity: Headache.Severity
  
  /// The selected severity in the button's parent view.
  var selectedSeverity: Headache.Severity? = nil
  
  /// The selected severity range in the button's parent view.
  var selectedSeverityRange: Headache.Severity.Range? = nil
  
  /// Whether or not the button should be drawn collapsed.
  var collapsed: Bool = false
  
  /// Whether the button represents a link.
  var link: Bool = false
  
  /// The button's action. If nil, then the button is drawn
  /// as a rectantle instead.
  var action: ((Headache.Severity) async throws -> Void)? = nil
  
  // MARK: Private properties
  
  /// The application's custom color scheme.
  @AppStorage(AppSettings.colorScheme) private var colorScheme: AppColorScheme = .multicolor
  
  /// The dimensions of the button's rectangle.
  private let dimension: CGFloat = 60.0
  
  /// Whether or not this button is the selected button.
  private var selected: Bool {
    if link {
      return severity == selectedSeverity
    }
    return (severity == selectedSeverity) || (selectedSeverityRange?.contains(severity) ?? false)
  }
  
  var body: some View {
    VStack {
      let content = ZStack {
        RoundedRectangle(cornerRadius: 12)
          .frame(width: dimension, height: dimension)
          .foregroundColor(selected ? severity.color(for: colorScheme) : Color.secondary.opacity(0.25))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(severity.color(for: colorScheme).opacity(0.25), lineWidth: 4.0)
          )
      }
      
      if link {
        Link(destination: URL(string: "myheadache://severity?rawValue=\(severity.rawValue)")!) {
          content
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundColor(selected ? severity.color(for: colorScheme) : Color.secondary.opacity(0.25))
        .cornerRadius(12)
      }
      else {
        if let action = action {
          AsyncButton {
            try await action(severity)
          } label: {
            content
          }
          .buttonStyle(BorderlessButtonStyle())
          .foregroundColor(selected ? severity.color(for: colorScheme) : Color.secondary.opacity(0.25))
          .cornerRadius(12)
        }
        else {
          RoundedRectangle(cornerRadius: 12)
            .frame(width: dimension, height: collapsed ? 8.0 : dimension)
            .foregroundColor(selected ? severity.color(for: colorScheme) : Color.secondary.opacity(0.25))
        }
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

