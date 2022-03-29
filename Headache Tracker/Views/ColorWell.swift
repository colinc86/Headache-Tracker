//
//  ColorWell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/26/22.
//

import IrregularGradient
import SwiftUI

struct ColorWell: View {
  
  /// The colors to display in the well.
  let colors: [Color]
  
  /// The well's background color.
  var backgroundColor: Color = Color(.systemBackground)
  
  @State var shouldAnimate = true
  
  // MARK: View body
  
  var body: some View {
    ZStack(alignment: .trailing) {
      Circle()
        .irregularGradient(
          colors: colors,
          backgroundColor: backgroundColor,
          shouldAnimate: $shouldAnimate,
          speed: 5)
      Circle()
        .inset(by: 2)
        .stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
    }
  }
}

struct ColorWell_Previews: PreviewProvider {
  static var previews: some View {
    ColorWell(colors: ColorTheme.system.wellColors)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
    
    ColorWell(colors: ColorTheme.grayscale.wellColors)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
    
    ColorWell(colors: ColorTheme.monokai.wellColors)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
    
    ColorWell(colors: ColorTheme.pink.wellColors)
      .previewLayout(.fixed(width: 50.0, height: 50.0))
  }
}
