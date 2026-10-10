//
//  MonthlyRecapView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI

/// The monthly "Your Patterns" recap: a calm, health-appropriate summary of
/// the month's headaches, streaks, and patterns — with a shareable poster.
struct MonthlyRecapView: View {

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// Dismisses the view.
  @Environment(\.dismiss) private var dismiss

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The loaded recap.
  @State private var recap: MonthlyRecap?

  /// Whether the recap is still loading.
  @State private var loading = true

  /// The rendered shareable poster, ready for the share sheet.
  @State private var shareURL: URL?

  // MARK: View body

  var body: some View {
    NavigationStack {
      Group {
        if let recap = recap, recap.hasData {
          content(recap)
        }
        else if loading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else {
          emptyState
        }
      }
      .navigationTitle("Your Patterns")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }

        ToolbarItem(placement: .primaryAction) {
          if let shareURL = shareURL {
            ShareLink(item: shareURL, preview: SharePreview("Your Patterns", image: Image(systemName: "sparkles"))) {
              Image(systemName: "square.and.arrow.up")
            }
          }
        }
      }
      .task {
        await load()
      }
    }
    .accentColor(colorTheme.baseColor)
  }

  // MARK: Content

  private func content(_ recap: MonthlyRecap) -> some View {
    ScrollView {
      VStack(spacing: Tokens.Spacing.lg) {
        RecapPoster(recap: recap, theme: colorTheme)
          .aspectRatio(RecapPoster.aspectRatio, contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
          .padding(.horizontal, Tokens.Spacing.md)
          .padding(.top, Tokens.Spacing.md)

        if !recap.topPatterns.isEmpty {
          patternsCard(recap)
        }

        Text("Shared with care — nothing here leaves your device until you send it.")
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, Tokens.Spacing.lg)
          .padding(.bottom, Tokens.Spacing.lg)
      }
    }
  }

  private func patternsCard(_ recap: MonthlyRecap) -> some View {
    Card(title: "What Moved Your Risk", systemImage: "waveform.path.ecg", foregroundColor: colorTheme.baseColor) {
      VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
        ForEach(Array(recap.topPatterns.enumerated()), id: \.offset) { _, pattern in
          Label(pattern, systemImage: "circle.fill")
            .labelStyle(.recapBullet)
            .font(.callout)
        }
      }
    }
    .padding(.horizontal, Tokens.Spacing.md)
  }

  private var emptyState: some View {
    VStack(spacing: Tokens.Spacing.md) {
      Image(systemName: "sparkles.rectangle.stack")
        .font(.system(size: 44))
        .foregroundColor(colorTheme.baseColor)
      Text("Your recap is taking shape")
        .font(.headline)
      Text("Log headaches through the month and your patterns will appear here.")
        .font(.callout)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(Tokens.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Loading

  // `@MainActor` so the `loading`/`recap` state mutations run on the main
  // thread — the awaited `monthlyRecap()` still does its work off-main on a
  // background Core Data context, and `renderPoster` is itself `@MainActor`.
  @MainActor private func load() async {
    loading = true
    do {
      let recap = try await headacheManager.monthlyRecap()
      self.recap = recap
      if recap.hasData {
        await renderPoster(recap)
      }
    }
    catch {
      logError("Error building monthly recap: \(error)")
    }
    loading = false
  }

  /// Renders the poster to a temp PNG for the share sheet.
  @MainActor private func renderPoster(_ recap: MonthlyRecap) async {
    let poster = RecapPoster(recap: recap, theme: colorTheme)
      .frame(width: RecapPoster.renderSize.width, height: RecapPoster.renderSize.height)
    let renderer = ImageRenderer(content: poster)
    renderer.scale = 3.0
    guard let image = renderer.uiImage, let data = image.pngData() else {
      return
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Your Patterns.png")
    try? data.write(to: url)
    shareURL = url
  }

}

/// A left-aligned bullet label style for recap patterns.
private struct RecapBulletLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
      configuration.icon
        .font(.system(size: 6))
        .foregroundColor(.secondary)
      configuration.title
    }
  }
}

private extension LabelStyle where Self == RecapBulletLabelStyle {
  static var recapBullet: RecapBulletLabelStyle { RecapBulletLabelStyle() }
}

/// The shareable recap poster — a self-contained, fixed-aspect card. Rendered
/// both inline and to a PNG via `ImageRenderer`, so it must not depend on the
/// surrounding environment.
struct RecapPoster: View {

  let recap: MonthlyRecap
  let theme: ColorTheme

  /// The poster's aspect ratio (portrait, story-friendly).
  static let aspectRatio: CGFloat = 0.62

  /// The pixel size to render the shareable image at (before scale).
  static let renderSize = CGSize(width: 360, height: 360 / aspectRatio)

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [theme.baseColor, theme.baseColor.opacity(0.65), theme.moderate.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 2) {
          Text("YOUR PATTERNS")
            .font(.caption.weight(.bold))
            .tracking(2)
            .opacity(0.85)
          Text(recap.monthTitle)
            .font(.title.weight(.bold))
        }

        Spacer(minLength: 0)

        // Headline stat.
        VStack(alignment: .leading, spacing: 0) {
          Text("\(recap.headacheFreeDays)")
            .font(.system(size: 76, weight: .heavy, design: .rounded))
          Text("headache-free \(recap.headacheFreeDays == 1 ? "day" : "days") of \(recap.totalDays)")
            .font(.headline)
            .opacity(0.9)
        }

        // Secondary stats.
        HStack(spacing: 14) {
          statTile(value: "\(recap.headacheCount)", label: recap.headacheCount == 1 ? "headache" : "headaches")
          statTile(value: "\(recap.longestFreeStreak)", label: "day streak")
        }

        if !recap.topPatterns.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("What moved your risk")
              .font(.subheadline.weight(.semibold))
              .opacity(0.9)
            ForEach(Array(recap.topPatterns.prefix(2).enumerated()), id: \.offset) { _, pattern in
              Text("• \(pattern)")
                .font(.footnote)
                .opacity(0.95)
                .lineLimit(1)
            }
          }
        }

        Spacer(minLength: 0)

        HStack(spacing: 6) {
          Image(systemName: "brain.head.profile")
          Text("Headache Tracker")
            .font(.footnote.weight(.semibold))
        }
        .opacity(0.9)
      }
      .foregroundStyle(.white)
      // The gradient takes the user's theme base color, several of which are
      // bright (Monokai cyan, Sunrise coral, Night periwinkle), leaving white
      // text low-contrast. A soft dark halo keeps this shareable poster legible
      // on any theme — imperceptible on dark bases, legibility-saving on light
      // ones. (Posters aren't the flat in-app surfaces the no-shadow rule governs.)
      .shadow(color: .black.opacity(0.28), radius: 2.5, x: 0, y: 1)
      .padding(26)
    }
  }

  private func statTile(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(value)
        .font(.title2.weight(.bold).monospacedDigit())
      Text(label)
        .font(.caption2)
        .opacity(0.85)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.18)))
    // Read the number and its unit as one phrase ("27, headache-free days")
    // instead of two disjoint VoiceOver stops.
    .accessibilityElement(children: .combine)
  }

}

struct MonthlyRecapView_Previews: PreviewProvider {
  static var previews: some View {
    RecapPoster(
      recap: MonthlyRecap(
        monthTitle: "July 2026",
        headacheCount: 3,
        totalDays: 18,
        headacheFreeDays: 15,
        longestFreeStreak: 9,
        bestWeek: .init(index: 1, onsets: 0),
        worstWeek: .init(index: 2, onsets: 2),
        topPatterns: ["Lower sleep before headaches", "Higher stress before headaches"]),
      theme: .system)
    .frame(width: 360, height: 360 / RecapPoster.aspectRatio)
    .previewLayout(.sizeThatFits)
  }
}
