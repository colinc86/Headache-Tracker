//
//  AsyncButton.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/8/22.
//

import SwiftUI

struct AsyncButton<Label: View>: View {
  
  enum ProgressMode {
    case hidden
    case replacingContent
    case beforeContent
    case afterContent
  }
  
  var role: ButtonRole? = nil
  var mode: ProgressMode = .hidden
  var alertTitle = ""
  let action: () async throws -> Void
  let label: () -> Label
  
  // MARK: Private properties
  
  /// The view's async in-progress state.
  @State private var inProgress = false
  
  /// The alert's message.
  @State private var alertMessage = ""
  
  /// Whether or not the alert is visible.
  @State private var showingAlert = false
  
  // MARK: View body
  
  var body: some View {
    HStack {
      if inProgress && mode == .beforeContent {
        ProgressView()
          .progressViewStyle(DefaultProgressViewStyle())
      }
      
      if inProgress && mode == .replacingContent {
        ProgressView()
          .progressViewStyle(DefaultProgressViewStyle())
      }
      else {
        Button(role: role, action: {
          Task {
            await setInProgress(true)
            
            do {
              try await action()
            }
            catch {
              await showAlert(error)
            }
            
            await setInProgress(false)
          }
        }, label: label)
          .disabled(inProgress)
          .confirmationAlert(isPresented: $showingAlert, title: alertTitle, message: alertMessage)
      }
      
      
      if inProgress && mode == .afterContent {
        Spacer()
        
        ProgressView()
          .progressViewStyle(DefaultProgressViewStyle())
      }
    }
  }
  
}

extension AsyncButton where Label == Text {
  
  init(_ title: String, role: ButtonRole? = nil, mode: ProgressMode = .hidden, action: @escaping () async throws -> Void) {
    self.init(role: role, mode: mode, alertTitle: title, action: action) {
      Text(title)
    }
  }
  
}

extension AsyncButton {
  
  /// Sets the in-progress state of the view.
  private func setInProgress(_ inProgress: Bool) async {
    await MainActor.run {
      withAnimation { self.inProgress = inProgress }
    }
  }
  
  /// Shows an alert to the user.
  ///
  /// - Parameter errpr: The alert's message.
  private func showAlert(_ error: Error) async {
    // Derive the message off-main (a pure read), then publish both pieces of
    // state together on the main actor — assigning `alertMessage` off-main is a
    // SwiftUI state mutation from a background thread and can leave the alert
    // showing a stale or empty message.
    let message: String
    if let describableError = error as? DescribableError {
      message = describableError.description
    }
    else {
      message = error.localizedDescription
    }

    await MainActor.run {
      alertMessage = message
      withAnimation { showingAlert = true }
    }
  }
  
}

struct AsyncButton_Previews: PreviewProvider {
  static var previews: some View {
    AsyncButton {
      // Do something
    } label: {
      Text("Async Button")
    }
    
    AsyncButton("Async Button") {
      // Do something
    }
  }
}
