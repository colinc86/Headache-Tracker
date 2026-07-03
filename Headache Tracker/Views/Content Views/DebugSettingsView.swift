//
//  DebugSettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import ApplicationKey
import DataController
import SwiftUI
import UniformTypeIdentifiers

struct DebugSettingsView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  // Preferences
  @AppStorage(Preferences.Debug.Keys.lastOutlookDate) var lastOutlookDate = Date()
  @AppStorage(Preferences.Debug.Keys.nextOutlookDate) var nextOutlookDate = Date()
  @AppStorage(Preferences.Debug.Keys.lastTrainingDate) var lastTrainingDate = Date()
  @AppStorage(Preferences.Debug.Keys.nextTrainingDate) var nextTrainingDate = Date()
  @AppStorage(Preferences.Debug.Keys.lastPredictionDate) var lastPredictionDate = Date()
  @AppStorage(Preferences.Debug.Keys.nextPredictionDate) var nextPredictionDate = Date()
  
  /// The application's not present training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "(severity.rawValue == %@) OR (severity == %@)", NSNumber(integerLiteral: Headache.Severity.notPresent.rawValue), NSNull()),
    animation: .default)
  private var notPresentTrainingData: FetchedResults<TrainingData>
  
  /// The application's present training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: Headache.Severity.unspecified.rawValue)),
    animation: .default)
  private var presentTrainingData: FetchedResults<TrainingData>
  
  /// The application's mild training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: Headache.Severity.mild.rawValue)),
    animation: .default)
  private var mildTrainingData: FetchedResults<TrainingData>
  
  /// The application's moderate training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: Headache.Severity.moderate.rawValue)),
    animation: .default)
  private var moderateTrainingData: FetchedResults<TrainingData>
  
  /// The application's severe training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: Headache.Severity.severe.rawValue)),
    animation: .default)
  private var severeTrainingData: FetchedResults<TrainingData>
  
  /// The apps current model evaluation calculated on appear.
  @State var evaluation: (accuracy: Double, brier: Double?, count: Int) = (0.0, nil, 0)
  
  @State var exportURL: URL? = nil
  @State var showingExportDocument: Bool = false
  @State var showingImportDocument: Bool = false
  
  var body: some View {
    Form {
      Section {
        NavigationLink {
          TrainingDataListView()
        } label: {
          Text("Training Data")
        }
        
        SubtitleCell(title: "Data Version", subtitle: Constants.trainingDataVersion)
        SubtitleCell(title: "Weather Version", subtitle: Constants.trainingDataWeatherVersion)
      }
      
      Section {
        SubtitleCell(title: "Severe", subtitle: "\(severeTrainingData.count)")
        SubtitleCell(title: "Moderate", subtitle: "\(moderateTrainingData.count)")
        SubtitleCell(title: "Mild", subtitle: "\(mildTrainingData.count)")
        SubtitleCell(title: "Present", subtitle: "\(presentTrainingData.count)")
        SubtitleCell(title: "Not Present", subtitle: "\(notPresentTrainingData.count)")
      }
      
      Section {
        SubtitleCell(title: "Risk Probability", subtitle: predictor.prediction.map({ String(format: "%0.1f%%", $0.probability * 100.0) }) ?? "N/A")
        SubtitleCell(title: "Risk Tier", subtitle: predictor.prediction?.tier.title ?? "N/A")
        SubtitleCell(title: "Top Factors", subtitle: (predictor.prediction?.topFactors.map({ $0.mlFeatureName }).joined(separator: ", ")).flatMap({ $0.isEmpty ? nil : $0 }) ?? "N/A")
      }
      
      Section {
        SubtitleCell(title: "Forecast Accuracy", subtitle: "\(String(format: "%0.1f%%", evaluation.accuracy * 100.0))")
        SubtitleCell(title: "Observed Brier", subtitle: evaluation.brier.map({ String(format: "%0.3f", $0) }) ?? "N/A")
        AsyncButton("Reset Evaluation", mode: .afterContent, action: headacheManager.resetEvaluation)
      } footer: {
        Text("Out of \(evaluation.count) resolved forecasts. Brier below 0.25 beats always guessing 50%.")
      }

      if let metrics = predictor.metrics {
        Section {
          if let accuracy = metrics.accuracy {
            SubtitleCell(title: "Validation Accuracy", subtitle: "\(String(format: "%0.1f%%", accuracy * 100.0)) (n=\(metrics.validationRowCount))")
          }
          if let brier = metrics.brier {
            SubtitleCell(title: "Validation Brier", subtitle: String(format: "%0.3f", brier))
          }
          SubtitleCell(title: "Calibrated", subtitle: metrics.isCalibrated ? "Yes" : "No (validation slice too small)")

          ForEach(metrics.calibrationBuckets, id: \.lowerBound) { bucket in
            SubtitleCell(
              title: String(format: "Bucket %0.0f%%+", bucket.lowerBound * 100.0),
              subtitle: String(format: "predicted %0.0f%%, observed %0.0f%% (n=%d)", bucket.meanPredicted * 100.0, bucket.observedRate * 100.0, bucket.count))
          }
        } footer: {
          Text("Measured on a held-out validation slice the model never trained on (trained \(metrics.trainedAt.formattedNonRelative())).")
        }
      }
      
      Section {
        AsyncButton("Train Models", mode: .afterContent, action: headacheManager.trainClassifiers)
      } footer: {
        Text("Models last trained \(predictor.modelUpdatedAt?.formattedNonRelative() ?? "N/A")")
      }
      
      Section {
        SubtitleCell(title: "Last Outlook", subtitle: "\(lastOutlookDate.formattedNonRelative())")
        SubtitleCell(title: "Next Outlook", subtitle: "\(nextOutlookDate.formattedNonRelative())")
        SubtitleCell(title: "Last Training", subtitle: "\(lastTrainingDate.formattedNonRelative())")
        SubtitleCell(title: "Next Training", subtitle: "\(nextTrainingDate.formattedNonRelative())")
        SubtitleCell(title: "Last Prediction", subtitle: "\(lastPredictionDate.formattedNonRelative())")
        SubtitleCell(title: "Next Prediction", subtitle: "\(nextPredictionDate.formattedNonRelative())")
      }
      
      Section {
        AsyncButton("Backup Database", mode: .afterContent, action: backupDatabase)
          .disabled(Preferences.Sync().storeIsSplit)
        Button("Restore Database", action: restoreDatabase)
          .disabled(Preferences.Sync().storeIsSplit)
          // Backup/restore copy a single store file; once the database is
          // split for iCloud sync they would silently miss the user-data
          // store, so both are disabled (iCloud is the offsite copy).
        AsyncButton("Initialize CloudKit Schema", mode: .replacingContent, action: initializeCloudKitSchema)
          .disabled(!Preferences.Sync().enabled)
      }
    }
    .navigationTitle("Debug Settings")
    .animation(.default, value: predictor.prediction)
    .task {
      do {
        evaluation = try await headacheManager.evaluation()
      }
      catch {
        logError("Error evaluating models: \(error)")
      }
    }
    .fileExporter(isPresented: $showingExportDocument, document: BackupDocument(url: exportURL), contentType: UTType(filenameExtension: "sqlite")!, onCompletion: exportDocumentAction)
    .fileImporter(isPresented: $showingImportDocument, allowedContentTypes: [UTType(filenameExtension: "sqlite")!], onCompletion: importDocumentAction)
  }
}

class BackupDocument: FileDocument {
  static var readableContentTypes: [UTType] {
    [UTType.database]
  }
  
  static var writableContentTypes: [UTType] {
    [UTType.database]
  }
  
  let url: URL?
  
  init(url: URL?) {
    self.url = url
  }
  
  required init(configuration: ReadConfiguration) throws {
    url = configuration.file.symbolicLinkDestinationURL
  }
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    if let url = url {
      return try FileWrapper(url: url)
    }
    else {
      throw NSError(domain: ApplicationKey(from: "backup"), code: NSFileNoSuchFileError)
    }
  }
}

// MARK: Private properties

extension DebugSettingsView {
  
  /// Pushes the record types to the CloudKit development schema. Only
  /// meaningful in DEBUG with sync enabled.
  func initializeCloudKitSchema() async throws {
    try DataController.shared.initializeCloudKitSchema(options: [])
  }

  func backupDatabase() async throws {
    exportURL = try await DataController.shared.backupDatabase()
    showingExportDocument = true
  }
  
  func restoreDatabase() {
    showingImportDocument = true
  }
  
  func exportDocumentAction(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      logDebug("Finished exporting database to file \(url)")
    case .failure(let error):
      logError("Error exporting database to file \(error)")
    }
  }
  
  func importDocumentAction(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      guard url.startAccessingSecurityScopedResource() else {
        return
      }
      
      Task {
        do {
          try await DataController.shared.restoreDatabase(from: url)
        }
        catch {
          logError("Error importing database from url \(url): \(error)")
        }
        
        url.stopAccessingSecurityScopedResource()
      }
    case .failure(let error):
      logError("Error importing database: \(error)")
    }
  }
  
}

struct DebugSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    DebugSettingsView()
      .environment(\.managedObjectContext, Previewing.CoreData.viewContext)
      .environmentObject(Previewing.headacheManager)
      .environmentObject(Previewing.Prediction.predictor)
  }
}
