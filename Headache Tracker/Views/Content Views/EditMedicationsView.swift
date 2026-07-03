//
//  EditMedicationsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/3/26.
//

import SwiftUI

/// The medication entry editor for a headache, presented as a sheet.
struct EditMedicationsView: View {

  /// The owning headache's identifier.
  let headacheIdentifier: UUID

  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// Dismisses the view.
  @Environment(\.dismiss) private var dismiss

  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme

  /// The headache's medication entries.
  @FetchRequest private var entries: FetchedResults<MedicationEntry>

  /// Recently used medication names for autocomplete.
  @State private var recentNames = [String]()

  /// The new entry's name field.
  @State private var newName = ""

  /// The new entry's taken-at date.
  @State private var newTakenAt = Date()

  // MARK: View body

  var body: some View {
    NavigationStack {
      Form {
        if !entries.isEmpty {
          Section {
            ForEach(entries, id: \.objectID) { entry in
              entryRow(entry)
            }
            .onDelete(perform: deleteEntries)
          } header: {
            SectionTitleView(title: "Logged")
          } footer: {
            SectionFooterView(title: "Rate each medication so the app can track what actually helps.")
          }
        }

        Section {
          TextField("Medication name", text: $newName)
            .autocorrectionDisabled()

          if !suggestedNames.isEmpty {
            FlexibleView(data: suggestedNames, spacing: 8, alignment: .leading) { name in
              Button(name) {
                newName = name
              }
              .buttonStyle(TagButtonStyle())
            }
          }

          DatePicker("Taken at", selection: $newTakenAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])

          AsyncButton("Add Medication", mode: .beforeContent, action: addEntry)
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
          SectionTitleView(title: "Add")
        }
      }
      .navigationTitle("Medications")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .task {
        await loadRecentNames()
      }
    }
    .accentColor(colorTheme.baseColor)
  }

  // MARK: Initializers

  init(headacheIdentifier: UUID) {
    self.headacheIdentifier = headacheIdentifier
    _entries = FetchRequest<MedicationEntry>(
      sortDescriptors: [NSSortDescriptor(key: "takenAt", ascending: true)],
      predicate: NSPredicate(format: "headache.identifier = %@", headacheIdentifier as NSUUID),
      animation: .default)
  }

  // MARK: Private properties

  private var suggestedNames: [String] {
    let typed = newName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let candidates = recentNames.filter { name in
      typed.isEmpty || name.lowercased().hasPrefix(typed)
    }
    return Array(candidates.prefix(5))
  }

  // MARK: Private methods

  private func entryRow(_ entry: MedicationEntry) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(entry.name ?? "Medication")
          .font(.callout)
        Spacer()
        if let takenAt = entry.takenAt {
          Text(Formatters.formatTime(takenAt))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Picker("Did it help?", selection: efficacyBinding(for: entry)) {
        ForEach(MedicationEntry.Efficacy.allCases.filter({ $0 != .unrated })) { efficacy in
          Text(efficacy.title).tag(efficacy)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(.vertical, 2)
  }

  private func efficacyBinding(for entry: MedicationEntry) -> Binding<MedicationEntry.Efficacy> {
    Binding {
      entry.efficacy
    } set: { newValue in
      guard let identifier = entry.identifier else { return }
      Task {
        do {
          try await headacheManager.updateMedication(identifier: identifier, efficacy: newValue)
        }
        catch {
          logError("Error updating medication efficacy: \(error)")
        }
      }
    }
  }

  private func addEntry() async throws {
    try await headacheManager.addMedication(name: newName, takenAt: newTakenAt, headacheIdentifier: headacheIdentifier)
    newName = ""
    newTakenAt = Date()
    await loadRecentNames()
  }

  private func deleteEntries(at offsets: IndexSet) {
    let identifiers = offsets.compactMap({ entries[$0].identifier })
    Task {
      for identifier in identifiers {
        do {
          try await headacheManager.deleteMedication(identifier: identifier)
        }
        catch {
          logError("Error deleting medication: \(error)")
        }
      }
    }
  }

  private func loadRecentNames() async {
    do {
      recentNames = try await headacheManager.recentMedicationNames()
    }
    catch {
      logError("Error loading recent medication names: \(error)")
    }
  }

}

struct EditMedicationsView_Previews: PreviewProvider {
  static var previews: some View {
    EditMedicationsView(headacheIdentifier: Previewing.CoreData.resolvedHeadache.identifier ?? UUID())
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
  }
}
