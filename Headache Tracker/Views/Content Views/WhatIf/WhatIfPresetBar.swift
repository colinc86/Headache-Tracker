//
//  WhatIfPresetBar.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/3/26.
//

import SwiftUI

/// One-tap scenarios as a horizontal chip row. A chip reads selected while
/// the sliders sit on its values; tapping it again resets.
struct WhatIfPresetBar: View {

  /// The presets on offer.
  let presets: [WhatIfPreset]

  /// Whether a preset's values currently hold.
  let isActive: (WhatIfPreset) -> Bool

  /// Called with the tapped preset.
  let onSelect: (WhatIfPreset) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      Text("Try a scenario")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, Tokens.Spacing.gutter)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Tokens.Spacing.sm) {
          ForEach(presets) { preset in
            Chip(
              title: preset.title,
              systemImage: preset.systemImage,
              style: isActive(preset) ? .selected : .unselected,
              action: { onSelect(preset) })
          }
        }
        .padding(.horizontal, Tokens.Spacing.gutter)
      }
      .scrollClipDisabled()
    }
  }

}
