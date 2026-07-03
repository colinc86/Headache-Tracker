//
//  DailyCheckInView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// The daily exposure check-in editor, presented as a sheet.
struct DailyCheckInView: View {

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// Dismisses the view.
  @Environment(\.dismiss) private var dismiss

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The day being edited.
  @State private var day = Date()

  /// The selected exposure kind raw values for the day.
  @State private var selectedKinds = Set<String>()

  /// Previously used custom kinds (beyond the built-ins).
  @State private var customKinds = [String]()

  /// The custom kind entry field.
  @State private var newCustomKind = ""

  // MARK: View body

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
        } footer: {
          SectionFooterView(title: "You can edit past days if you forgot to check in.")
        }

        Section {
          FlexibleView(data: ExposureKind.allCases.map({ $0.rawValue }), spacing: 8, alignment: .leading) { kind in
            kindChip(kind)
          }
          .padding(.vertical, 4)
        } header: {
          SectionTitleView(title: "Exposures")
        } footer: {
          SectionFooterView(title: "Tap everything that applies to this day.")
        }

        Section {
          if !customKinds.isEmpty {
            FlexibleView(data: customKinds, spacing: 8, alignment: .leading) { kind in
              kindChip(kind)
            }
            .padding(.vertical, 4)
          }

          HStack {
            TextField("Add custom…", text: $newCustomKind)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
              .onSubmit(addCustomKind)

            if !sanitizedCustomKind.isEmpty {
              Button("Add", action: addCustomKind)
                .foregroundColor(colorTheme.baseColor)
            }
          }
        } header: {
          SectionTitleView(title: "Custom")
        } footer: {
          SectionFooterView(title: "Custom exposures are recorded and shown, but only the built-in kinds are analyzed for correlations right now.")
        }
      }
      .navigationTitle("Daily Check-In")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          AsyncButton("Save", mode: .replacingContent, action: save)
        }
      }
      .task {
        await load()
      }
      .onChange(of: day) { _, _ in
        Task {
          await loadDay()
        }
      }
    }
    .accentColor(colorTheme.baseColor)
  }

  // MARK: Private properties

  private var sanitizedCustomKind: String {
    return newCustomKind
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
      .replacingOccurrences(of: " ", with: "-")
      .lowercased()
  }

  // MARK: Private methods

  private func kindChip(_ kind: String) -> some View {
    let selected = selectedKinds.contains(kind)
    let title = ExposureKind(rawValue: kind)?.title ?? kind.capitalized
    let systemImage = ExposureKind(rawValue: kind)?.systemImage ?? "tag.fill"

    return Chip(
      title: title,
      systemImage: selected ? "checkmark.circle.fill" : systemImage,
      style: selected ? .selected : .unselected) {
        if selected {
          selectedKinds.remove(kind)
        }
        else {
          selectedKinds.insert(kind)
        }
      }
  }

  private func addCustomKind() {
    let kind = sanitizedCustomKind
    guard !kind.isEmpty else {
      return
    }

    if !customKinds.contains(kind) && ExposureKind(rawValue: kind) == nil {
      customKinds.append(kind)
    }
    selectedKinds.insert(kind)
    newCustomKind = ""
  }

  private func load() async {
    do {
      let builtIn = Set(ExposureKind.allCases.map({ $0.rawValue }))
      customKinds = try await headacheManager.exposureKinds().filter({ !builtIn.contains($0) })
    }
    catch {
      logError("Error loading exposure kinds: \(error)")
    }
    await loadDay()
  }

  private func loadDay() async {
    do {
      let snapshots = try await headacheManager.exposures(on: day)
      selectedKinds = Set(snapshots.map({ $0.kind }))
      for kind in selectedKinds where ExposureKind(rawValue: kind) == nil && !customKinds.contains(kind) {
        customKinds.append(kind)
      }
    }
    catch {
      logError("Error loading exposures: \(error)")
    }
  }

  private func save() async throws {
    try await headacheManager.setExposures(selectedKinds, on: day)
    dismiss()
  }

}

struct DailyCheckInView_Previews: PreviewProvider {
  static var previews: some View {
    DailyCheckInView()
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
  }
}
