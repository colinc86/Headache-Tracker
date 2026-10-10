//
//  SeveritySelectionView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

/// How a severity selection view responds to taps.
enum SeveritySelectionMode {

  /// A non-interactive display.
  case display

  /// Runs a closure on tap (in-app).
  case action((Headache.Severity) async throws -> Void)

  /// Runs `LogSeverityIntent` on tap (widgets) — logs directly in the app
  /// process without opening the app.
  case widget

}

/// Draws a horizontal severity level indicator.
struct SeveritySelectionView: View {
  
  // MARK: Public properties
  
  /// The headache's level to display.
  let currentSeverity: Headache.Severity?
  
  /// The headache's severity range to display.
  var severityRange: Headache.Severity.Range? = nil
  
  /// The collapsed state of the view.
  var collapsed: Bool = false
  
  /// The view's interaction mode.
  var mode: SeveritySelectionMode = .display
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  // MARK: View body
  
  var body: some View {
    Card(title: "Severity", systemImage: "dial.max.fill", foregroundColor: colorTheme.cyan) {
      HStack {
        Spacer(minLength: 0.0)
        HStack(spacing: 0.0) {
          ForEach(0 ..< 5) { i in
            SeverityButton(
              severity: severity(for: i),
              selectedSeverity: currentSeverity,
              selectedSeverityRange: severityRange,
              collapsed: collapsed,
              mode: mode)
            
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
    SeveritySelectionView(currentSeverity: nil, severityRange: nil, collapsed: false)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: .mild, severityRange: nil, collapsed: false)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: nil, severityRange: Headache.Severity.Range(uncheckedBounds: (.notPresent, .severe)), collapsed: false)
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
      .previewLayout(PreviewLayout.fixed(width: 428, height: 130))
    
    SeveritySelectionView(currentSeverity: nil, severityRange: nil, collapsed: true)
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
  
  /// The button's interaction mode.
  var mode: SeveritySelectionMode = .display
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  /// The dimensions of the button's rectangle.
  private let dimension: CGFloat = 60.0
  
  /// Whether or not this button is the selected button.
  private var selected: Bool {
    if case .widget = mode {
      return severity == selectedSeverity
    }
    return (severity == selectedSeverity) || (selectedSeverityRange?.contains(severity) ?? false)
  }
  
  var body: some View {
    VStack {
      let content = ZStack {
        RoundedRectangle(cornerRadius: Tokens.Radius.md)
          .frame(width: dimension, height: dimension)
          .foregroundColor(selected ? colorTheme.color(for: severity) : Color.secondary.opacity(0.25))
          .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
              .stroke(colorTheme.color(for: severity).opacity(0.25), lineWidth: 4.0)
          )
      }
      
      switch mode {
      case .widget:
        // The intent executes in the app process; no confirm dialog and no
        // app launch. (The myheadache:// URL path remains for deep links.)
        Button(intent: LogSeverityIntent(severity: SeverityAppEnum(severity))) {
          content
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundColor(selected ? colorTheme.color(for: severity) : Color.secondary.opacity(0.25))
        .cornerRadius(Tokens.Radius.md)
      case .action(let action):
        AsyncButton {
          try await action(severity)
        } label: {
          content
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundColor(selected ? colorTheme.color(for: severity) : Color.secondary.opacity(0.25))
        .cornerRadius(Tokens.Radius.md)
      case .display:
        RoundedRectangle(cornerRadius: Tokens.Radius.md)
          .frame(width: dimension, height: collapsed ? 8.0 : dimension)
          .foregroundColor(selected ? colorTheme.color(for: severity) : Color.secondary.opacity(0.25))
      }
      
      Text(severity.title)
        .font(.caption)
        .foregroundColor(selectedSeverity == nil && selectedSeverityRange == nil ? .primary : (selected ? .primary : .secondary))
    }
    .animation(Tokens.Motion.selection, value: selected)
    // `.combine` (not `.ignore`) merges the bar and label into one spoken
    // element while PRESERVING the child button's activation. `.ignore` discards
    // the button's action, so the interactive severity buttons — in the app and
    // the widget alike — were announced as buttons but did nothing on a VoiceOver
    // double-tap. For display mode (no button) the two are equivalent.
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(severity.title) severity")
    .accessibilityAddTraits(accessibilityTraits)
  }

  /// The button's traits: interactive modes read as buttons, and the
  /// current selection is announced.
  private var accessibilityTraits: AccessibilityTraits {
    var traits = AccessibilityTraits()
    if case .display = mode {} else {
      _ = traits.insert(.isButton)
    }
    if selected {
      _ = traits.insert(.isSelected)
    }
    return traits
  }
  
}

struct SeverityButton_Previews: PreviewProvider {
  static var previews: some View {
    SeverityButton(severity: .notPresent, selectedSeverity: nil, collapsed: false)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .unspecified, selectedSeverity: .unspecified, collapsed: false)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .mild, selectedSeverity: nil, collapsed: true)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .moderate, selectedSeverity: .moderate, collapsed: true)
      .previewLayout(.fixed(width: 100, height: 100))
    
    SeverityButton(severity: .severe, selectedSeverity: nil, collapsed: false)
      .previewLayout(.fixed(width: 100, height: 100))
  }
}

