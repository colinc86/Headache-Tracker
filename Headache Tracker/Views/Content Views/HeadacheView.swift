//
//  HeadacheView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/7/22.
//

import SwiftUI

struct HeadacheView: View {
  @Environment(\.presentationMode) var mode: Binding<PresentationMode>
  
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  @StateObject var headache: Headache
  
  @State var alertTitle = ""
  @State var alertMessage = ""
  @State var showingAlert = false
  
  private let formatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.minute, .hour, .day]
    formatter.maximumUnitCount = 2
    return formatter
  }()
  
  var body: some View {
    List {
      Section("Headache") {
        SubtitleCell(title: "Onset", subtitle: headache.startTime?.formatted() ?? "N/A")
        SubtitleCell(title: "Duration", subtitle: formatter.string(from: headache.duration) ?? "0 minutes")
        SubtitleCell(title: "Severity", subtitle: headache.severityDescription)
        SubtitleCell(title: "Status", subtitle: headache.resolved ? "Resolved" : "Unresolved")
      }
      
      Section("Progression") {
        ForEach(headache.severitiesArray, id: \.self) { severity in
          SubtitleCell(title: severity.severity.title, subtitle: severity.startTime?.formatted() ?? "N/A")
        }
      }
      
      Section {
        HStack {
          Spacer()
          Button("Delete Headache", action: delete)
            .foregroundColor(.red)
          Spacer()
        }
      }
    }
    .navigationTitle("Headache")
    .navigationBarTitleDisplayMode(.inline)
    .alert(alertTitle, isPresented: $showingAlert) {
      Button("OK", action: { showingAlert = false })
    } message: {
      Text(alertMessage)
    }
  }
  
}

extension HeadacheView {
  
  private func showAlert(_ title: String, _ message: String) {
    alertTitle = title
    alertMessage = message
    showingAlert = true
  }
  
  private func delete() {
    if let identifier = headache.identifier {
      headacheManager.deleteHeadache(identifier: identifier) { error in
        if let error = error {
          showAlert("Unable to Delete Headache", error.localizedDescription)
        }
        else {
          mode.wrappedValue.dismiss()
        }
      }
    }
  }
  
}

struct HeadacheView_Previews: PreviewProvider {
  static var previews: some View {
    HeadacheView(headache: Previewing.CoreData.headache)
  }
}
