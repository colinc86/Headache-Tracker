//
//  ConfirmationAlert.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/8/22.
//

import SwiftUI

struct ConfirmationAlert: ViewModifier {
  
  // MARK: Public properties
  
  /// Whether or not we are showing an alert.
  @Binding var isPresented: Bool
  
  /// The alert's title.
  let title: String
  
  /// The alert's message.
  let message: String
  
  // MARK: Body content
  
  func body(content: Content) -> some View {
    content
      .alert(isPresented: $isPresented) {
        Alert(
          title: Text(title),
          message: Text(message),
          dismissButton: Alert.Button.default(Text("OK"), action: {
            withAnimation { isPresented = false }
          })
        )
      }
  }
  
}

extension View {
  func confirmationAlert(isPresented: Binding<Bool>, title: String, message: String) -> some View {
    modifier(
      ConfirmationAlert(
        isPresented: isPresented,
        title: title,
        message: message
      )
    )
  }
}
