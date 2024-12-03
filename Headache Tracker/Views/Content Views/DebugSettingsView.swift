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
  @State var evaluation: (Double, Double, Int) = (0.0, 0.0, 0)
  
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
        SubtitleCell(title: "Outlook Classifier", subtitle: "\(predictor.prediction?.outlookClassifierOutput.prediction.rawValue ?? "")")
        SubtitleCell(title: "Outlook Probability", subtitle: "\(predictor.prediction?.outlookClassifierOutput.probability?.percentFormat() ?? "N/A")")
        SubtitleCell(title: "Severity Classifier", subtitle: "\(predictor.prediction?.severityClassifierOutput.prediction.title ?? "")")
        SubtitleCell(title: "Severity Probability", subtitle: "\(predictor.prediction?.severityClassifierOutput.probability?.percentFormat() ?? "N/A")")
        SubtitleCell(title: "Onset Regressor", subtitle: "\(predictor.prediction?.onsetRegressorOutput.prediction.formattedNonRelative() ?? "0.0")")
        SubtitleCell(title: "Duration Regressor", subtitle: "\(predictor.prediction?.durationRegressorOutput.prediction ?? 0.0)")
      }
      
      Section {
        SubtitleCell(title: "Outlook Evaluation", subtitle: "\(String(format: "%0.1f%%", evaluation.0 * 100.0))")
        SubtitleCell(title: "Severity Evaluation", subtitle: "\(String(format: "%0.1f%%", evaluation.1 * 100.0))")
        AsyncButton("Reset Evaluation", mode: .afterContent, action: headacheManager.resetEvaluation)
      } footer: {
        Text("Out of \(evaluation.2) samples.")
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
        Button("Restore Database", action: restoreDatabase)
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
