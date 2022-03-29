//
//  ColorThemeView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/25/22.
//

import SwiftUI

struct ColorThemeView: View {
  
  /// The color theme to display.
  let theme: ColorTheme
  
  /// The view's title alignment.
  var titleAlignment: HorizontalAlignment = .leading
  
  // MARK: View body
  
  var body: some View {
    GeometryReader { geometry in
      HStack {
        if titleAlignment == .leading {
          ColorWell(colors: theme.wellColors, backgroundColor: theme.baseColor, shouldAnimate: theme.multicolor)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
          Text(theme.name)
          Spacer()
        }
        else if titleAlignment == .center {
          Spacer()
          Text(theme.name)
          Spacer()
          ColorWell(colors: theme.wellColors, backgroundColor: theme.baseColor, shouldAnimate: theme.multicolor)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
        }
        else if titleAlignment == .trailing {
          Spacer()
          Text(theme.name)
          ColorWell(colors: theme.wellColors, backgroundColor: theme.baseColor, shouldAnimate: theme.multicolor)
            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
        }
      }
    }
  }
}

struct ColorThemeView_Previews: PreviewProvider {
  static var previews: some View {
    ColorThemeView(theme: .system)
  }
}
