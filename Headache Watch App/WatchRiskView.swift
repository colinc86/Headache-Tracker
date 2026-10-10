//
//  WatchRiskView.swift
//  Headache Watch App
//
//  Created by Colin Campbell on 7/18/26.
//

import SwiftUI

/// The watch app's home: the current forecast (or active headache) plus
/// wrist quick-logging.
struct WatchRiskView: View {

  @Environment(\.scenePhase) private var scenePhase

  @State private var risk: WatchShared.Risk?
  @State private var activeSeverity: WatchShared.Severity?

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        if let severity = activeSeverity {
          activeHeadache(severity)
        }
        else {
          forecast
        }

        Divider()

        quickLog
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("Headache")
    .onAppear(perform: refresh)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { refresh() }
    }
    .onReceive(NotificationCenter.default.publisher(for: WatchConnectivityClient.contextDidChange)) { _ in
      refresh()
    }
  }

  // MARK: Sections

  @ViewBuilder private var forecast: some View {
    if let risk = risk {
      let tier = WatchShared.Tier(probability: risk.probability)
      VStack(spacing: 6) {
        ZStack {
          Circle()
            .stroke(tier.color.opacity(0.2), lineWidth: 8)
          Circle()
            .trim(from: 0, to: min(max(risk.probability, 0), 1))
            .stroke(tier.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
          VStack(spacing: 0) {
            Text(WatchShared.percent(risk.probability))
              .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("24h")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 96, height: 96)

        Text(tier.title)
          .font(.headline)
          .foregroundStyle(tier.color)

        if let short = risk.shortProbability, short >= 0 {
          Text("\(WatchShared.percent(short)) within 12h")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 4)
    }
    else {
      VStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.title2)
          .foregroundStyle(.secondary)
        Text("No forecast yet")
          .font(.headline)
        Text("Open the app on your phone to build your model.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 8)
    }
  }

  private func activeHeadache(_ severity: WatchShared.Severity) -> some View {
    VStack(spacing: 6) {
      Image(systemName: "brain.head.profile")
        .font(.title)
        .foregroundStyle(severity.color)
      Text("\(severity.title) Headache")
        .font(.headline)
      Text("In progress")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.top, 6)
  }

  private var quickLog: some View {
    VStack(spacing: 6) {
      Text(activeSeverity == nil ? "Log a headache" : "Update")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      ForEach([WatchShared.Severity.mild, .moderate, .severe]) { severity in
        Button {
          log(severity)
        } label: {
          Text(severity.title)
            .frame(maxWidth: .infinity)
        }
        .tint(severity.color)
      }

      if activeSeverity != nil {
        Button {
          log(.notPresent)
        } label: {
          Label("Resolve", systemImage: "checkmark")
            .frame(maxWidth: .infinity)
        }
        .tint(.green)
      }
    }
  }

  // MARK: Actions

  private func refresh() {
    risk = WatchShared.currentRisk()
    activeSeverity = WatchShared.activeSeverity()
  }

  private func log(_ severity: WatchShared.Severity) {
    WatchConnectivityClient.shared.log(severity)
    // Optimistically reflect the change; the phone confirms via the shared
    // defaults on the next refresh.
    activeSeverity = severity == .notPresent ? nil : severity
  }

}

struct WatchRiskView_Previews: PreviewProvider {
  static var previews: some View {
    WatchRiskView()
  }
}
