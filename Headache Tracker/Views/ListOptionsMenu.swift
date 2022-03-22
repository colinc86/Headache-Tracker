//
//  ListOptionsMenu.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/21/22.
//

import SwiftUI

struct ListOptionsMenu: View {
  
  /// Whether the onset view should be shown.
  @AppStorage(AppSettings.ListOptions.onset) private var onset = true
  
  /// Whether the duration view should be shown.
  @AppStorage(AppSettings.ListOptions.duration) private var duration = true
  
  /// Whether the progression view should be shown.
  @AppStorage(AppSettings.ListOptions.progression) private var progression = true
  
  /// Whether the outlook view should be shown.
  @AppStorage(AppSettings.ListOptions.outlook) private var outlook = true
  
  /// Whether the severity view should be shown.
  @AppStorage(AppSettings.ListOptions.severity) private var severity = true
  
  var body: some View {
    Menu {
      Section {
        Button {
          onset = !onset
        } label: {
          if onset {
            Label("Onset", systemImage: "checkmark")
          }
          else {
            Text("Onset")
          }
        }
        
        Button {
          duration = !duration
        } label: {
          if duration {
            Label("Duration", systemImage: "checkmark")
          }
          else {
            Text("Duration")
          }
        }
        
        Button {
          progression = !progression
        } label: {
          if progression {
            Label("Progression", systemImage: "checkmark")
          }
          else {
            Text("Progression")
          }
        }
      }
      
      Section {
        Button {
          outlook = !outlook
        } label: {
          if outlook {
            Label("Outlook", systemImage: "checkmark")
          }
          else {
            Text("Outlook")
          }
        }
        
        Button {
          severity = !severity
        } label: {
          if severity {
            Label("Severity", systemImage: "checkmark")
          }
          else {
            Text("Severity")
          }
        }
      }
    } label: {
      Label("View Options", systemImage: "list.bullet.below.rectangle")
    }
  }
}

struct ListOptionsMenu_Previews: PreviewProvider {
  static var previews: some View {
    ListOptionsMenu()
  }
}
