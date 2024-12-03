//
//  FeedbackView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import SwiftUI

struct FeedbackView: View {
  
  enum ViewType {
    case bug
    case feedback
    
    var navigationTitle: String {
      switch self {
      case .bug: return "Bug Report"
      case .feedback: return "Share Feedback"
      }
    }
    
    var title: String {
      switch self {
      case .bug: return "Bug"
      case .feedback: return "Feedback"
      }
    }
  }
  
  /// The type of feedback view to display.
  let type: ViewType
  
  // MARK: Private properties
  
  /// The view's presentation mode.
  @Environment(\.presentationMode) private var presentationMode
  
  /// The view's title.
  @State private var title: String = ""
  
  /// The view's message.
  @State private var message: String = ""
  
  /// Whether the view is submitting the feedback.
  @State private var submitting: Bool = false
  
  // MARK: View body
  
  var body: some View {
    NavigationView {
      Form {
        Section {
          TextField("Title", text: $title)
        } header: {
          Text(type.title)
        }
        
        Section {
          TextEditor(text: $message)
            .frame(minHeight: 200.0)
        } header: {
          Text("Description")
        }
      }
      .navigationTitle(type.navigationTitle)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel, action: cancel)
            .disabled(submitting)
        }
        
        ToolbarItem(placement: .confirmationAction) {
          if submitting {
            ProgressView()
              .progressViewStyle(DefaultProgressViewStyle())
          }
          else {
            Button("Submit", action: submit)
          }
        }
      }
    }
  }
}

// MARK: Private methods

extension FeedbackView {
  
  private func cancel() {
    dismiss()
  }
  
  private func submit() {
    withAnimation {
      submitting = true
    }
    
    var url: URL?
    
    if let url = url {
      logInfo("Submitted \(type.title.lowercased()) with url \(url.absoluteString).")
    }
    else {
      logInfo("Unable to submit feedback.")
    }
    
    dismiss()
  }
  
  private func dismiss() {
    presentationMode.wrappedValue.dismiss()
  }
  
}

struct FeedbackView_Previews: PreviewProvider {
  static var previews: some View {
    FeedbackView(type: .feedback)
    FeedbackView(type: .bug)
  }
}
