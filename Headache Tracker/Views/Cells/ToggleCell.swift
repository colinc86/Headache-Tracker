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

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The toggle switch's title.
  let title: String

  var data: HealthKitData? = nil

  /// The toggle switch's state.
  @Binding var state: Bool

  /// The name of the system image.
  var systemName: String? = nil

  /// The color of the image. Defaults to the active theme's base color.
  var imageForegroundColor: Color? = nil

  var valueChanged: ((HealthKitData?, Bool) -> Void)? = nil

  var body: some View {
    HStack {
      if let systemName = systemName {
        Image(systemName: systemName)
          .foregroundColor(imageForegroundColor ?? colorTheme.baseColor)
      }
      Toggle(title, isOn: $state)
        .tint(colorTheme.baseColor)
        .onChange(of: state) { _, newValue in
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
