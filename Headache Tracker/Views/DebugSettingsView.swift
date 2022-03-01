//
//  DebugSettingsView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import Logger
import SwiftUI
import HealthKit

struct DebugSettingsView: View {
  
  // MARK: Private properties
  
  /// The main view context.
  @Environment(\.managedObjectContext) private var viewContext
  
  /// The app's headache manager.
  @EnvironmentObject private var headacheManager: HeadacheManager
  
  /// The app's headache predictor.
  @EnvironmentObject private var predictor: Predictor
  
  /// A debug setting to show all views in the prediction section.
  @AppStorage(AppSettings.debugShowAllViews) private var debugShowAllViews = false
  
  /// The application's not present training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "(severity.rawValue == %@) OR (severity == %@)", NSNumber(integerLiteral: HKCategoryValueSeverity.notPresent.rawValue), NSNull()),
    animation: .default)
  private var notPresentTrainingData: FetchedResults<TrainingData>
  
  /// The application's present training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: HKCategoryValueSeverity.unspecified.rawValue)),
    animation: .default)
  private var presentTrainingData: FetchedResults<TrainingData>
  
  /// The application's mild training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: HKCategoryValueSeverity.mild.rawValue)),
    animation: .default)
  private var mildTrainingData: FetchedResults<TrainingData>
  
  /// The application's moderate training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: HKCategoryValueSeverity.moderate.rawValue)),
    animation: .default)
  private var moderateTrainingData: FetchedResults<TrainingData>
  
  /// The application's severe training data.
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \TrainingData.timestamp, ascending: false)],
    predicate: NSPredicate(format: "severity.rawValue == %@", NSNumber(integerLiteral: HKCategoryValueSeverity.severe.rawValue)),
    animation: .default)
  private var severeTrainingData: FetchedResults<TrainingData>
  
  var body: some View {
    Section {
      Toggle("Show All Views", isOn: $debugShowAllViews)
    } header: {
      Text("Debug")
    }
    
    Section {
      NavigationLink {
        TrainingDataListView()
          .environment(\.managedObjectContext, viewContext)
      } label: {
        Text("Training Data")
      }
      
      SubtitleCell(title: "Severe", subtitle: "\(severeTrainingData.count)")
      SubtitleCell(title: "Moderate", subtitle: "\(moderateTrainingData.count)")
      SubtitleCell(title: "Mild", subtitle: "\(mildTrainingData.count)")
      SubtitleCell(title: "Present", subtitle: "\(presentTrainingData.count)")
      SubtitleCell(title: "Not Present", subtitle: "\(notPresentTrainingData.count)")
    }
    
    Section {
      SubtitleCell(title: "Outlook Classifier", subtitle: "\(predictor.prediction?.outlookClassifierOutput.prediction.rawValue ?? "")")
      SubtitleCell(title: "Severity Classifier", subtitle: "\(predictor.prediction?.severityClassifierOutput.prediction.title ?? "")")
      SubtitleCell(title: "Onset Regressor", subtitle: "\(predictor.prediction?.onsetRegressorOutput.prediction ?? Date())")
      SubtitleCell(title: "Duration Regressor", subtitle: "\(predictor.prediction?.durationRegressorOutput.prediction ?? 0.0)")
    }
    
    Section {
      Button("Train Models") {
        headacheManager.trainClassifiers { error in
          if let error = error {
            logError("Error training classifiers: \(error)")
          }
        }
      }
      
      Button("Clean Data") {
        headacheManager.cleanTrainingData { error in
          if let error = error {
            logError("Error cleaning data: \(error)")
          }
        }
      }
    } footer: {
      Text("Models last updated at \(predictor.modelUpdatedAt?.formatted() ?? "N/A")")
    }
    
    
  }
}

struct DebugSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    DebugSettingsView()
      .environment(\.managedObjectContext, Previewing.CoreData.controller.container.viewContext)
  }
}
