//
//  SignalsWidgetView.swift
//  Headache Tracker WidgetExtension
//
//  Created by Colin Campbell on 9/30/26.
//

import SwiftUI
import WidgetKit

/// The signals widget's family switch.
struct SignalsWidgetView: View {

  /// The entry.
  let entry: RiskWidgetEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  private var snapshot: RiskSnapshot {
    return entry.snapshot
  }

  private var tint24: Color {
    return snapshot.tier24.map({ colorTheme.color(for: $0) }) ?? .secondary
  }

  private var isLarge: Bool {
    return family == .systemLarge
  }

  private var maxMagnitude: Double {
    return snapshot.signals.compactMap({ $0.delta }).map(abs).max() ?? 0.0
  }

  private var raising: [RiskSnapshot.Signal] {
    return Array(snapshot.raising.prefix(isLarge ? 4 : 2))
  }

  private var easing: [RiskSnapshot.Signal] {
    return Array(snapshot.easing.prefix(isLarge ? 3 : 1))
  }

  var body: some View {
    Group {
      if snapshot.isEmpty && snapshot.activeHeadache == nil {
        RiskEmptyStateView()
      }
      else {
        content
      }
    }
    .riskWidgetPlaceholder(snapshot.isPlaceholder)
    .accessibilityElement(children: .contain)
  }

  // MARK: Content

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
      header

      if snapshot.signals.isEmpty {
        Text("Signals appear after your next refresh.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      else if isLarge {
        group(title: "Raising your risk", signals: raising)
        group(title: "In your favor", signals: easing)
        WidgetHairline()
          .padding(.vertical, Tokens.Spacing.xxs)
        fingerprint
        Spacer(minLength: 0)
      }
      else {
        // Full-width rows: two columns leave titles like "Heart Rate
        // Variability" no room at this width.
        group(title: "Raising your risk", signals: raising)
        group(title: "In your favor", signals: easing)
        Spacer(minLength: 0)
      }
    }
    .riskWidgetStale(snapshot.isStale)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      if let headache = snapshot.activeHeadache {
        ActiveHeadacheBadge(headache: headache, tint: colorTheme.color(for: headache.severity), compact: true, showsHint: false)
        Spacer()
        Text("As of the last forecast")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      else {
        if let probability = snapshot.probability24, let tier = snapshot.tier24 {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs) {
            Text(RiskFormat.percent(probability))
              .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
              .foregroundStyle(renderingMode == .fullColor ? tint24 : .primary)
              .widgetAccentable()
            Text(RiskFormat.shortTier(tier))
              .font(.system(.caption, design: .rounded).weight(.semibold))
              .foregroundStyle(renderingMode == .fullColor ? tint24 : .secondary)
          }
          .privacySensitive()
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(RiskFormat.spokenPercent(probability)), \(RiskFormat.shortTier(tier).lowercased())\(snapshot.interval24.map({ ", \(RiskFormat.spokenRange($0))" }) ?? "").")
        }
        Spacer()
        if snapshot.interval24 != nil || snapshot.coverage != nil {
          HStack(spacing: Tokens.Spacing.xs) {
            if let accuracy = snapshot.accuracy {
              Text(accuracy.text)
                .font(.system(.caption2, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            ForecastConfidenceBadge(confidence: snapshot.confidence, monochrome: renderingMode != .fullColor)
          }
          .privacySensitive()
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(snapshot.accuracy.map({ "The model has been \($0.spokenText). " }) ?? "")Confidence \(snapshot.confidence.title.lowercased()).")
        }
        else {
          Text(snapshot.hasSignedSignals ? "What's driving it" : "Model view")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
    }
  }

  private func group(title: String, signals: [RiskSnapshot.Signal]) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      Text(title)
        .font(.system(size: 9, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
      if signals.isEmpty {
        Text("Nothing notable")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      else {
        ForEach(signals) { signal in
          ContributionRow(
            signal: signal,
            maxMagnitude: maxMagnitude,
            raisingTint: colorTheme.color(for: .high),
            easingTint: colorTheme.color(for: .low),
            iconTint: colorTheme.baseColor,
            showsCaption: isLarge)
          .privacySensitive()
        }
      }
    }
  }

  // MARK: Fingerprint

  /// The summed contribution per signal domain, strongest first.
  private var domainSums: [(domain: SignalDomain, sum: Double)] {
    guard snapshot.hasSignedSignals else {
      return []
    }
    var sums = [SignalDomain: Double]()
    for signal in snapshot.signals {
      guard let feature = signal.feature, let delta = signal.delta else {
        continue
      }
      sums[feature.domain, default: 0.0] += delta
    }
    return SignalDomain.allCases
      .compactMap { domain -> (SignalDomain, Double)? in
        guard let sum = sums[domain], abs(sum) >= 0.005 else {
          return nil
        }
        return (domain, sum)
      }
      .map({ (domain: $0.0, sum: $0.1) })
  }

  private var fingerprint: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
      Text("Your fingerprint")
        .font(.system(size: 9, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
      if snapshot.hasSignedSignals {
        let sums = domainSums
        let maxSum = sums.map({ abs($0.sum) }).max() ?? 0.0
        ForEach(sums, id: \.domain) { entry in
          DomainFingerprintRow(
            domain: entry.domain,
            sum: entry.sum,
            maxMagnitude: maxSum,
            isProfileLeader: snapshot.profileDomains.first == entry.domain,
            raisingTint: colorTheme.color(for: .high),
            easingTint: colorTheme.color(for: .low))
          .privacySensitive()
        }
      }
      else {
        Text("Train a model on this device to see per-signal effects.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

}

/// One signal domain's net contribution as a diverging bar from a center
/// tick: raising to the right, easing to the left.
struct DomainFingerprintRow: View {

  /// The domain.
  let domain: SignalDomain

  /// The summed contribution.
  let sum: Double

  /// The largest |sum| across domains.
  let maxMagnitude: Double

  /// Whether this is the user's leading domain in Insights.
  let isProfileLeader: Bool

  /// The raising tint.
  let raisingTint: Color

  /// The easing tint.
  let easingTint: Color

  @Environment(\.widgetRenderingMode) private var renderingMode

  private var barTint: Color {
    if renderingMode != .fullColor {
      return sum > 0 ? .primary : Color.primary.opacity(0.35)
    }
    return (sum > 0 ? raisingTint : easingTint).opacity(0.85)
  }

  var body: some View {
    HStack(spacing: Tokens.Spacing.sm) {
      Image(systemName: domain.systemImage)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(width: 18)
      HStack(spacing: 3) {
        Text(domain.title)
          .font(.caption)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        if isProfileLeader {
          Image(systemName: "star.fill")
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 92, alignment: .leading)

      GeometryReader { geometry in
        let half = geometry.size.width / 2.0
        let width = max(3.0, half * CGFloat(min(abs(sum) / max(maxMagnitude, 0.001), 1.0)))
        ZStack(alignment: .center) {
          Capsule().fill(.quaternary)
          Rectangle()
            .fill(.secondary)
            .frame(width: 1, height: 7)
          Capsule()
            .fill(barTint)
            .frame(width: width, height: 5)
            .offset(x: sum > 0 ? width / 2.0 : -width / 2.0)
            .widgetAccentable(sum > 0)
        }
      }
      .frame(height: 7)

      Text(RiskFormat.signedPercent(sum))
        .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
        .foregroundStyle(.secondary)
        .fixedSize()
        .frame(minWidth: 30, alignment: .trailing)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(domain.title), net \(sum > 0 ? "raising" : "easing") by \(Int((abs(sum) * 100.0).rounded())) percent.")
  }

}
