//
//  DestructiveConfirmationDialog.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import SwiftUI

struct DestructiveConfirmationDialog: ViewModifier {
  
  // MARK: Public properties
  
  /// The alert's title.
  let title: String
  
  /// Whether or not we are showing an alert.
  @Binding var isPresented: Bool
  
  /// The title of the non-cancellation button.
  let destructiveActionTitle: String
  
  /// The alert's non-cancellation action.
  let destructiveAction: () -> Void
  
  // MARK: Body content
  
  func body(content: Content) -> some View {
    content
      .confirmationDialog(title, isPresented: $isPresented) {
        Button(destructiveActionTitle, role: .destructive, action: destructiveAction)
      }
  }
  
}

extension View {
  func destructiveConfirmationDialog(title: String, isPresented: Binding<Bool>, destructiveActionTitle: String, destructiveAction: @escaping () -> Void) -> some View {
    modifier(
      DestructiveConfirmationDialog(
        title: title,
        isPresented: isPresented,
        destructiveActionTitle: destructiveActionTitle,
        destructiveAction: destructiveAction)
    )
  }
}
