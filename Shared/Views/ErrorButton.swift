//
//  ErrorButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/9/22.
//

import SwiftUI

struct ErrorButton<Label: View>: View {
  
  var role: ButtonRole? = nil
  var alertTitle = ""
  let action: () throws -> Void
  let label: () -> Label
  
  // MARK: Private properties
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  // MARK: View body
  
  var body: some View {
    Button(role: role, action: {
      do {
        try action()
      }
      catch {
        showAlert(error)
      }
    }, label: label)
    .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
  }
  
}

extension ErrorButton where Label == Text {
  
  init(_ title: String, role: ButtonRole? = nil, action: @escaping () throws -> Void) {
    self.init(role: role, alertTitle: title, action: action) {
      Text(title)
    }
  }
  
}

extension ErrorButton {
  
  /// Shows an alert to the user.
  ///
  /// - Parameter errpr: The alert's message.
  private func showAlert(_ error: Error) {
    if let describableError = error as? DescribableError {
      alertMessage = describableError.description
    }
    else {
      alertMessage = error.localizedDescription
    }
    
    withAnimation { showingAlert = true }
  }
  
}

struct ErrorButton_Previews: PreviewProvider {
  static var previews: some View {
    ErrorButton {
      // Do something
    } label: {
      Text("Error Button")
    }
    
    ErrorButton("Error Button") {
      // Do something
    }
  }
}
