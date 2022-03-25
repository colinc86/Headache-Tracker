//
//  DebugSettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import DataController
import SwiftUI

struct DebugSettingsView: View {
  
  // MARK: Private properties
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.Debug.debugLastOutlookDate) private var debugLastOutlookDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.Debug.debugNextOutlookDate) private var debugNextOutlookDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.Debug.debugLastTrainingDate) private var debugLastTrainingDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.Debug.debugNextTrainingDate) private var debugNextTrainingDate: Date?
  
  /// A debug last outlook date setting.
  @AppStorage(AppSettings.Debug.debugLastPredictionDate) private var debugLastPredictionDate: Date?
  
  /// A debug next outlook date setting.
  @AppStorage(AppSettings.Debug.debugNextPredictionDate) private var debugNextPredictionDate: Date?
  
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
  
  @State var evaluation: (Double, Double, Int) = (0.0, 0.0, 0)
  
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
        SubtitleCell(title: "Last Outlook", subtitle: "\(debugLastOutlookDate?.formattedNonRelative() ?? "N/A")")
        SubtitleCell(title: "Next Outlook", subtitle: "\(debugNextOutlookDate?.formattedNonRelative() ?? "N/A")")
        SubtitleCell(title: "Last Training", subtitle: "\(debugLastTrainingDate?.formattedNonRelative() ?? "N/A")")
        SubtitleCell(title: "Next Training", subtitle: "\(debugNextTrainingDate?.formattedNonRelative() ?? "N/A")")
        SubtitleCell(title: "Last Prediction", subtitle: "\(debugLastPredictionDate?.formattedNonRelative() ?? "N/A")")
        SubtitleCell(title: "Next Prediction", subtitle: "\(debugNextPredictionDate?.formattedNonRelative() ?? "N/A")")
      }
      
      Section {
        AsyncButton("Backup Database", mode: .afterContent, action: DataController.shared.backupDatabase)
        AsyncButton("Restore Database", mode: .afterContent, action: DataController.shared.restoreDatabase)
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
