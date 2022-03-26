//
//  ColorSchemeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/25/22.
//

import IrregularGradient
import SwiftUI

struct ColorSchemeView: View {
  let scheme: AppColorScheme
  var titleAlignment: HorizontalAlignment = .leading
  
  var body: some View {
    GeometryReader { geometry in
      HStack {
        if titleAlignment == .leading {
          ColorWell(scheme: scheme, shouldAnimate: true)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
          Text(scheme.title)
          Spacer()
        }
        else if titleAlignment == .center {
          Spacer()
          Text(scheme.title)
          Spacer()
          ColorWell(scheme: scheme, shouldAnimate: true)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
        }
        else if titleAlignment == .trailing {
          Spacer()
          Text(scheme.title)
          ColorWell(scheme: scheme, shouldAnimate: true)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
        }
      }
    }
  }
}

struct ColorSchemeView_Previews: PreviewProvider {
  static var previews: some View {
    ColorSchemeView(scheme: .accentColor)
      .previewLayout(.fixed(width: 428, height: 30))
    
    ColorSchemeView(scheme: .multicolor)
      .previewLayout(.fixed(width: 428, height: 30))
    
    ColorSchemeView(scheme: .pink)
      .previewLayout(.fixed(width: 428, height: 30))
    
    ColorSchemeView(scheme: .pink, titleAlignment: .center)
      .previewLayout(.fixed(width: 428, height: 30))
    
    ColorSchemeView(scheme: .pink, titleAlignment: .trailing)
      .previewLayout(.fixed(width: 428, height: 30))
      .foregroundColor(.secondary)
  }
}
