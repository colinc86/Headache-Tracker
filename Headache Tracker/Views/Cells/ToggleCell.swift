//
//  ToggleCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/15/22.
//

import SwiftUI

struct ToggleCell: View {
  
  /// The health kit manager.
  @EnvironmentObject private var healthKitManager: HealthKitManager
  
  /// The toggle switch's title.
  let title: String
  
  var data: HealthKitData? = nil
  
  /// The toggle switch's state.
  @Binding var state: Bool
  
  /// The name of the system image.
  var systemName: String? = nil
  
  /// The color of the image.
  var imageForegroundColor: Color = .accentColor
  
  var valueChanged: ((HealthKitData?, Bool) -> Void)? = nil
  
  var body: some View {
    HStack {
      if let systemName = systemName {
        Image(systemName: systemName)
          .foregroundColor(imageForegroundColor)
      }
      Toggle(title, isOn: $state)
        .tint(.accentColor)
        .onChange(of: state) { newValue in
          valueChanged?(data, newValue)
        }
    }
  }
  
}

struct ToggleCell_Previews: PreviewProvider {
  @State static var state = false
  static var previews: some View {
    ToggleCell(title: "Toggle Cell", data: .stepCount, state: $state, systemName: "clock", valueChanged: { _, _ in
      
    })
      .previewLayout(PreviewLayout.fixed(width: 428, height: 20))
  }
}
