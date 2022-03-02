//
//  FeedbackView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import BugfenderSDK
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
  
  @Environment(\.presentationMode) private var presentationMode
  
  let type: ViewType
  
  @State private var title: String = ""
  @State private var message: String = ""
  @State private var submitting: Bool = false
  
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
    switch type {
    case .bug: url = Bugfender.sendIssueReturningUrl(withTitle: title, text: message)
    case .feedback: url = Bugfender.sendUserFeedbackReturningUrl(withSubject: title, message: message)
    }
    
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
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
    
    FeedbackView(type: .bug)
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
