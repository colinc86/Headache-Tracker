//
//  ColorWell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import SwiftUI

struct ColorWell: View {
  let scheme: AppColorScheme
  @State var shouldAnimate = true
  
  var body: some View {
    ZStack(alignment: .trailing) {
      Circle()
        .irregularGradient(
          colors: scheme.wellColors,
          backgroundColor: scheme.backgroundColor,
          shouldAnimate: $shouldAnimate, speed: 5)
      Circle()
        .inset(by: 2)
        .stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
    }
  }
}

struct ColorWell_Previews: PreviewProvider {
  static var previews: some View {
    ColorWell(scheme: .accentColor)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
    
    ColorWell(scheme: .multicolor)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
    
    ColorWell(scheme: .pink)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
  }
}
