//
//  HeadachesView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/6/22.
//

import SwiftUI

/// Shows a list of all unresolved and resolved headaches.
struct HeadachesView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager

  /// The unresolveed headaches fetch request.
  /// Returns a list of all unresolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: false)),
    animation: .default)
  private var unresolvedHeadaches: FetchedResults<Headache>
  
  /// The resolveed headaches fetch request.
  /// Returns a list of all resolved headaches.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Headache.createdAt, ascending: false)],
    predicate: NSPredicate(format: "resolved = %@", NSNumber(booleanLiteral: true)),
    animation: .default)
  private var resolvedHeadaches: FetchedResults<Headache>
  
  /// Whether the view is showing the add headache modal.
  @State private var showingAddHeadache: Bool = false

  /// The headache a swipe-to-delete is awaiting confirmation for.
  @State private var pendingDelete: Headache?

  // The statistics period.
  @AppStorage(Preferences.Filters.Keys.count) private var filterCount = Preferences.Filters.Defaults.count
  @AppStorage(Preferences.Filters.Keys.unit) private var filterUnit = Preferences.Filters.Defaults.unit

  /// Rebuilds the statistics when the period changes.
  @State private var statsIdentifier = UUID()

  // MARK: View body
  
  var body: some View {
    NavigationStack {
      List {
        if !resolvedHeadaches.isEmpty {
          HeadacheStatsSections(filterUnit: filterUnit, filterCount: filterCount)
            .id(statsIdentifier)
        }

        if unresolvedHeadaches.isEmpty && resolvedHeadaches.isEmpty {
          Section {
            Text("No headaches logged yet. Tap + to add one.")
              .font(.callout)
              .foregroundColor(.secondary)
          }
        }

        if unresolvedHeadaches.count > 0 {
          Section {
            ForEach(unresolvedHeadaches.sorted(by: HeadachesView.byOnsetDescending), id: \.objectID) { headache in
              NavigationLink {
                HeadacheView(headache: headache)
              } label: {
                HeadacheCell(headache: headache)
              }
              .swipeActions(edge: .trailing) { deleteSwipeButton(for: headache) }
            }
          } header: {
            SectionTitleView(title: "Unresolved")
          }
        }

        if resolvedHeadaches.count > 0 {
          Section {
            ForEach(resolvedHeadaches.sorted(by: HeadachesView.byOnsetDescending), id: \.objectID) { headache in
              NavigationLink {
                HeadacheView(headache: headache)
              } label: {
                HeadacheCell(headache: headache)
              }
              .swipeActions(edge: .trailing) { deleteSwipeButton(for: headache) }
            }
          } header: {
            SectionTitleView(title: "All Headaches")
          }
        }
      }
      .navigationTitle("Headaches")
      .onChange(of: filterCount) { _, _ in statsIdentifier = UUID() }
      .onChange(of: filterUnit) { _, newValue in changedFilterUnit(newValue) }
      .toolbar {
        // The statistics period, as a menu.
        ToolbarItem(placement: .topBarLeading) {
          Menu {
            Picker("Period", selection: $filterUnit) {
              Text("Days").tag(FilterUnit.day)
              Text("Weeks").tag(FilterUnit.week)
              Text("Months").tag(FilterUnit.month)
              Text("Years").tag(FilterUnit.year)
            }
            Picker("Amount", selection: $filterCount) {
              ForEach(filterUnit.filterCountRange, id: \.self) { i in
                Text("\(i)").tag(i)
              }
            }
          } label: {
            HStack(spacing: Tokens.Spacing.xs) {
              Image(systemName: "calendar")
              Text("Last \(filterCount) \(filterUnit.rawValue)\(filterCount == 1 ? "" : "s")")
              Image(systemName: "chevron.down")
                .font(.caption2)
            }
            .font(.callout)
          }
        }

        ToolbarItem(placement: .automatic) {
          Button(action: addHeadache) {
            Label("Add", systemImage: "plus")
          }
        }
      }
      .confirmationDialog(
        "Delete this headache?",
        isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
        presenting: pendingDelete
      ) { headache in
        Button("Delete", role: .destructive) { delete(headache) }
        Button("Cancel", role: .cancel) { pendingDelete = nil }
      } message: { _ in
        Text("This removes the headache and its severity history. Any entries written to the Health app are kept.")
      }
    }
    .sheet(isPresented: $showingAddHeadache, onDismiss: nil) {
      NavigationStack {
        AddHeadacheView(headacheManager: headacheManager)
      }
    }
  }
  
}

// MARK: Private methods

extension HeadachesView {

  /// Keeps the count inside the new unit's range, then rebuilds the stats.
  private func changedFilterUnit(_ newValue: FilterUnit) {
    if filterCount < newValue.filterCountRange.lowerBound {
      filterCount = newValue.filterCountRange.lowerBound
    }
    else if filterCount > newValue.filterCountRange.upperBound - 1 {
      filterCount = newValue.filterCountRange.upperBound - 1
    }
    statsIdentifier = UUID()
  }

  private func addHeadache() {
    withAnimation { showingAddHeadache = true }
  }

  /// The trailing swipe action that arms deletion for a headache. Full deletion
  /// (with the option to also remove HealthKit entries) still lives in the
  /// detail view; this convenience path keeps Health data by default.
  @ViewBuilder private func deleteSwipeButton(for headache: Headache) -> some View {
    Button(role: .destructive) {
      pendingDelete = headache
    } label: {
      Label("Delete", systemImage: "trash")
    }
  }

  /// Deletes the given headache, keeping any HealthKit entries.
  private func delete(_ headache: Headache) {
    let identifier = headache.identifier
    pendingDelete = nil
    Task {
      do {
        try await headacheManager.deleteHeadache(identifier: identifier, deleteHealthKitData: false)
      }
      catch {
        logError("Error deleting headache from list: \(error)")
      }
    }
  }

  /// Orders headaches by when they actually occurred (onset), newest first.
  /// The fetch is sorted by `createdAt` (a stored attribute Core Data can sort
  /// on), but `startTime` is computed, so the display re-sorts here — otherwise
  /// a back-logged headache (created now, onset days ago) would jump to the top
  /// of the list even though the cell shows its past onset.
  static func byOnsetDescending(_ a: Headache, _ b: Headache) -> Bool {
    return (a.startTime ?? .distantPast) > (b.startTime ?? .distantPast)
  }

}

struct HeadachesView_Previews: PreviewProvider {
  static var previews: some View {
    HeadachesView()
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.alertManager)
      .environmentObject(Previewing.Prediction.predictor)
      .environmentObject(Previewing.healthKitManager)
  }
}
