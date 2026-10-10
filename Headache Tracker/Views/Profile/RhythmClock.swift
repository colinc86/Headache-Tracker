//
//  RhythmClock.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import SwiftUI

/// When headaches start, as a 24-hour dial: each slice is an hour (midnight at
/// the top, running clockwise), each ring a weekday (Sunday innermost), and a
/// cell's intensity is how many headaches began then.
struct RhythmClock: View {

  /// Onset counts by weekday (0 = Sunday) and hour.
  let rhythm: [[Int]]

  /// The cells' tint.
  let tint: Color

  /// The center text, e.g. the busiest window.
  let centerTitle: String?

  /// The center caption.
  let centerCaption: String?

  private var maximum: Int {
    return max(rhythm.flatMap({ $0 }).max() ?? 0, 1)
  }

  var body: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width, geometry.size.height)
      let center = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
      let inner = size * 0.2
      let outer = size * 0.36
      let ring = (outer - inner) / 7.0

      ZStack {
        Canvas { context, _ in
          for weekday in 0 ..< 7 {
            let radiusIn = inner + ring * CGFloat(weekday) + 0.75
            let radiusOut = inner + ring * CGFloat(weekday + 1) - 0.75
            for hour in 0 ..< 24 {
              let start = Angle.degrees(-90.0 + Double(hour) * 15.0 + 0.8)
              let end = Angle.degrees(-90.0 + Double(hour + 1) * 15.0 - 0.8)
              var cell = Path()
              cell.addArc(center: center, radius: radiusOut, startAngle: start, endAngle: end, clockwise: false)
              cell.addArc(center: center, radius: radiusIn, startAngle: end, endAngle: start, clockwise: true)
              cell.closeSubpath()
              let count = weekday < rhythm.count && hour < rhythm[weekday].count ? rhythm[weekday][hour] : 0
              let style: Color = count == 0 ? Color.secondary.opacity(0.08) : tint.opacity(0.3 + 0.7 * Double(count) / Double(maximum))
              context.fill(cell, with: .color(style))
            }
          }

          // Hour labels at the quarters.
          for (hour, label) in [(0, "12 AM"), (6, "6 AM"), (12, "12 PM"), (18, "6 PM")] {
            let angle = -Double.pi / 2.0 + Double(hour) * Double.pi / 12.0
            let radius = outer + size * 0.07
            let position = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            context.draw(Text(label).font(.caption2).foregroundColor(.secondary), at: position)
          }
        }

        VStack(spacing: 2) {
          if let centerTitle = centerTitle {
            Text(centerTitle)
              .font(.system(.footnote, design: .rounded).weight(.bold))
              .multilineTextAlignment(.center)
          }
          if let centerCaption = centerCaption {
            Text(centerCaption)
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        .frame(width: inner * 1.8)
        .position(center)
      }
    }
    .aspectRatio(1.0, contentMode: .fit)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    let total = rhythm.flatMap({ $0 }).reduce(0, +)
    guard total > 0 else {
      return "No headache onsets in this period."
    }
    var text = "\(total) headache onsets by hour and weekday."
    if let centerTitle = centerTitle {
      text += " Most often \(centerTitle)."
    }
    return text
  }

}
