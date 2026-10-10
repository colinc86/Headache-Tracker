//
//  SignatureGlyph.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 10/4/26.
//

import IrregularGradient
import SwiftUI

/// The user's headache signature: one petal per signal domain, its length the
/// strength of that domain's strongest confident association, around a living
/// gradient core in the app's aura motif. Domains without a confident pattern
/// are faint stubs, so the shape itself says "a sleep person" or "a weather
/// person" at a glance.
struct SignatureGlyph: View {

  /// Strength per domain (|r| of its strongest confident association).
  let strengths: [SignalDomain: Double]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  @State private var animateCore = false
  @State private var bloom = 0.0

  /// The strength that fills a petal completely.
  static let fullStrength = 0.6

  private var domains: [SignalDomain] {
    return SignalDomain.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })
  }

  private var isStill: Bool {
    return reduceMotion || ProcessInfo.processInfo.arguments.contains("--uitest-seed")
  }

  var body: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width, geometry.size.height)
      let center = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
      let inner = size * 0.15
      let outer = size * 0.40

      ZStack {
        Canvas { context, _ in
          // Guide rings.
          for fraction in [0.5, 1.0] {
            let radius = inner + (outer - inner) * fraction
            let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
            context.stroke(ring, with: .color(.secondary.opacity(0.18)), style: StrokeStyle(lineWidth: 1.0, dash: [2.0, 4.0]))
          }

          for (index, domain) in domains.enumerated() {
            let angle = angleFor(index)
            let strength = strengths[domain] ?? 0.0
            let fill = strength > 0 ? min(strength / SignatureGlyph.fullStrength, 1.0) : 0.0
            let length = inner + (outer - inner) * CGFloat(strength > 0 ? 0.18 + 0.82 * fill : 0.14)
            let petal = petalPath(center: center, angle: angle, inner: inner * 0.92, length: length, width: strength > 0 ? 0.36 : 0.22)
            let color = colorTheme.color(for: domain)
            if strength > 0 {
              let tip = point(center: center, angle: angle, radius: length)
              context.fill(petal, with: .linearGradient(
                Gradient(colors: [color.opacity(0.25), color.opacity(0.95)]),
                startPoint: center,
                endPoint: tip))
              context.stroke(petal, with: .color(color.opacity(0.6)), lineWidth: 1.0)
            }
            else {
              context.fill(petal, with: .color(.secondary.opacity(0.12)))
            }
          }
        }
        // Petals bloom outward from the core on first appearance.
        .scaleEffect(0.55 + 0.45 * bloom)
        .opacity(bloom)

        // The core: the aura motif.
        Circle()
          .irregularGradient(
            colors: domains.filter({ (strengths[$0] ?? 0) > 0 }).map({ colorTheme.color(for: $0) }).padded(with: colorTheme.wellColors),
            backgroundColor: colorTheme.baseColor.opacity(0.4),
            shouldAnimate: $animateCore,
            speed: 2)
          .frame(width: inner * 1.7, height: inner * 1.7)
          .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
          .position(center)

        // Domain icons beyond each petal.
        ForEach(Array(domains.enumerated()), id: \.element) { index, domain in
          let active = (strengths[domain] ?? 0) > 0
          Image(systemName: domain.systemImage)
            .font(.system(size: size * 0.055, weight: .semibold))
            .foregroundColor(active ? colorTheme.color(for: domain) : Color.secondary.opacity(0.45))
            .position(point(center: center, angle: angleFor(index), radius: outer + size * 0.07))
        }
      }
    }
    .aspectRatio(1.0, contentMode: .fit)
    .onAppear {
      animateCore = !isStill
      if isStill {
        bloom = 1.0
      }
      else {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.72)) { bloom = 1.0 }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  // MARK: Geometry

  private func angleFor(_ index: Int) -> Double {
    return -Double.pi / 2.0 + Double(index) * 2.0 * Double.pi / Double(domains.count)
  }

  private func point(center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
    return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
  }

  /// A teardrop petal from the core outward.
  private func petalPath(center: CGPoint, angle: Double, inner: CGFloat, length: CGFloat, width: Double) -> Path {
    var path = Path()
    let left = point(center: center, angle: angle - width / 2.0, radius: inner)
    let right = point(center: center, angle: angle + width / 2.0, radius: inner)
    let tip = point(center: center, angle: angle, radius: length)
    let reach = inner + (length - inner) * 0.72
    path.move(to: left)
    path.addQuadCurve(to: tip, control: point(center: center, angle: angle - width * 0.55, radius: reach))
    path.addQuadCurve(to: right, control: point(center: center, angle: angle + width * 0.55, radius: reach))
    path.closeSubpath()
    return path
  }

  private var accessibilityText: String {
    let ranked = strengths.filter({ $0.value > 0 }).sorted(by: { $0.value > $1.value }).map({ $0.key.title })
    guard !ranked.isEmpty else {
      return "Your headache signature is still forming."
    }
    return "Your headache signature: strongest in \(TemplateSummaryWriter.joined(ranked))."
  }

}

private extension Array where Element == Color {

  /// The colors, topped up from a fallback so the gradient always has a few.
  func padded(with fallback: [Color]) -> [Color] {
    var colors = self
    for color in fallback where colors.count < 3 {
      colors.append(color)
    }
    return colors
  }

}
