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
  
  // Scheduling timestamps. These are read through `Preferences.Debug`, NOT
  // `@AppStorage`: the Refresher writes them via `@UserDefault`, which stores a
  // native `Date` (NSDate). `@AppStorage<Date>` decodes through Date's
  // `RawRepresentable` ISO-string conformance, so `string(forKey:)` returns nil
  // for a natively-stored date and every field silently fell back to `Date()`
  // (always showing "now"). Reading the optional `Date?` also lets unset fields
  // render "N/A" instead of a bogus current time.
  private let debugPreferences = Preferences.Debug()

  /// Whether training evaluates and may ship the personalized model.
  @AppStorage(Preferences.Debug.Keys.personalizationEnabled) private var personalizationEnabled = Preferences.Debug.Defaults.personalizationEnabled

  /// Whether training fits the bagged ensemble behind the forecast's range.
  @AppStorage(Preferences.Debug.Keys.ensembleEnabled) private var ensembleEnabled = Preferences.Debug.Defaults.ensembleEnabled
  
  /// The apps current model evaluation calculated on appear.
  @State var evaluation: (accuracy: Double, brier: Double?, count: Int) = (0.0, nil, 0)

  /// The observed evaluation for the shorter (12h) horizon.
  @State var shortEvaluation: (accuracy: Double, brier: Double?, count: Int) = (0.0, nil, 0)

  /// The training-row counts by derived outlook label, loaded on appear.
  /// Severity is no longer a stored field (the single risk classifier derives
  /// its label from headache intervals at train time), so these are computed
  /// rather than fetched per-severity.
  @State var outlookCounts: (positive: Int, negative: Int, inHeadache: Int, total: Int) = (0, 0, 0, 0)

  /// Rows whose trailing-window context is still to be back-filled.
  @State var contextLackingCount: Int = 0

  /// The resolved 24h forecasts, for the prospective record.
  @State var evaluationPoints = [EvaluationPoint]()

  /// The resolved forecasts from the last two weeks.
  private var recentEvaluationCount: Int {
    let cutoff = Date().addingTimeInterval(-14.0 * 86400.0)
    return evaluationPoints.lazy.filter({ $0.date >= cutoff }).count
  }
  
  @State var exportURL: URL? = nil
  @State var showingExportDocument: Bool = false
  @State var showingImportDocument: Bool = false

  /// The live location + weather the app is actually reading.
  @State private var snapshot: HeadacheManager.LocationWeatherSnapshot?

  /// The result of a manual weather recompute.
  @State private var recomputeResult: String?

  /// The temperature baked into the current cached forecast — what "Why" and
  /// Signals display. Compare against Live Temperature above: if Live is right
  /// but this is wrong, the forecast is just stale (tap Recompute Forecast).
  private var forecastTemperature: String {
    guard let celsius = predictor.prediction?.input.weatherStatistics?.currentTemperature else {
      return "N/A"
    }
    return String(format: "%.1f°C / %.1f°F", celsius, celsius * 9.0 / 5.0 + 32.0)
  }

  var body: some View {
    Form {
      Section {
        SubtitleCell(title: "Coordinate", subtitle: snapshot?.coordinate ?? "loading…")
        SubtitleCell(title: "Resolved Place", subtitle: snapshot?.place ?? "loading…")
        SubtitleCell(title: "Live Temperature", subtitle: snapshot?.temperature ?? "loading…")
        SubtitleCell(title: "Forecast Temperature", subtitle: forecastTemperature)
        AsyncButton("Refresh Location Reading", mode: .afterContent) {
          snapshot = await headacheManager.locationWeatherSnapshot()
        }
        AsyncButton("Recompute Forecast Now", mode: .afterContent) {
          // Directly recompute the live forecast (bypasses the pull-to-refresh
          // throttle) so "Why"/Signals pick up the corrected weather.
          try await headacheManager.createPredict(create: .never, inWidget: false)
        }
        AsyncButton("Recompute All Weather", mode: .afterContent) {
          let result = try await headacheManager.recomputeAllWeather()
          var message = "Updated \(result.updated) rows at their own logged locations."
          if result.skippedNoLocation > 0 {
            message += " \(result.skippedNoLocation) had no stored location and were left as-is."
          }
          recomputeResult = message
          snapshot = await headacheManager.locationWeatherSnapshot()
        }
      } header: {
        Text("Location & Weather")
      } footer: {
        Text(recomputeResult ?? "Recompute re-pulls every row's weather at the coordinate that row was logged at (each row stores its own), so rows logged while travelling get that city's weather — not wherever you are now. The reading above is just the current live location for reference.")
      }

      Section {
        NavigationLink {
          TrainingDataListView()
        } label: {
          Text("Training Data")
        }

        SubtitleCell(title: "Data Version", subtitle: Constants.trainingDataVersion)
        SubtitleCell(title: "Weather Version", subtitle: Constants.trainingDataWeatherVersion)
        SubtitleCell(title: "Context Version", subtitle: Constants.trainingDataContextVersion)
        SubtitleCell(title: "Rows Lacking Context", subtitle: "\(contextLackingCount)")
      }
      
      Section {
        SubtitleCell(title: "Total Rows", subtitle: "\(outlookCounts.total)")
        SubtitleCell(title: "Positive (24h onset)", subtitle: "\(outlookCounts.positive)")
        SubtitleCell(title: "Negative (clear)", subtitle: "\(outlookCounts.negative)")
        SubtitleCell(title: "In-Headache (excluded)", subtitle: "\(outlookCounts.inHeadache)")
      } footer: {
        Text("The risk classifier trains on positive vs. negative rows; in-headache rows are excluded.")
      }
      
      Section {
        SubtitleCell(title: "Risk Probability", subtitle: predictor.prediction.map({ String(format: "%0.1f%%", $0.probability * 100.0) }) ?? "N/A")
        SubtitleCell(title: "Risk Tier", subtitle: predictor.prediction?.tier.title ?? "N/A")
        SubtitleCell(title: "Risk (12h)", subtitle: predictor.prediction?.shortProbability.map({ String(format: "%0.1f%%", $0 * 100.0) }) ?? "N/A")
        SubtitleCell(title: "Range (24h)", subtitle: predictor.prediction?.interval.map({ String(format: "%0.1f–%0.1f%% (width %0.2f)", $0.lower * 100.0, $0.upper * 100.0, $0.width) }) ?? "N/A")
        SubtitleCell(title: "Coverage", subtitle: predictor.prediction?.coverage?.summary ?? "N/A")
        SubtitleCell(title: "Confidence", subtitle: predictor.prediction.map({ "\($0.confidence.title) — \($0.confidence.caption)" }) ?? "N/A")
        SubtitleCell(title: "Top Factors", subtitle: (predictor.prediction?.topFactors.map({ $0.contributionDescription }).joined(separator: ", ")).flatMap({ $0.isEmpty ? nil : $0 }) ?? "N/A")
      }
      
      Section {
        SubtitleCell(title: "Forecast Accuracy", subtitle: evaluation.count > 0 ? String(format: "%0.1f%%", evaluation.accuracy * 100.0) : "N/A")
        SubtitleCell(title: "Observed Brier", subtitle: evaluation.brier.map({ String(format: "%0.3f", $0) }) ?? "N/A")
        SubtitleCell(title: "Observed AUC", subtitle: ProspectiveAccuracy.summary(evaluationPoints).auc.map({ String(format: "%0.3f", $0) }) ?? "N/A")
        SubtitleCell(title: "Resolved Forecasts", subtitle: "\(evaluation.count) (last 14d: \(recentEvaluationCount))")
        AsyncButton("Reset Evaluation", mode: .afterContent, action: headacheManager.resetEvaluation)
      } header: {
        Text("Observed (24h)")
      } footer: {
        Text("Out of \(evaluation.count) resolved forecasts, recorded hourly from the background refresh as well as when the app is opened. Brier below 0.25 beats always guessing 50%.")
      }

      if shortEvaluation.count > 0 {
        Section {
          SubtitleCell(title: "Forecast Accuracy", subtitle: "\(String(format: "%0.1f%%", shortEvaluation.accuracy * 100.0))")
          SubtitleCell(title: "Observed Brier", subtitle: shortEvaluation.brier.map({ String(format: "%0.3f", $0) }) ?? "N/A")
        } header: {
          Text("Observed (12h)")
        } footer: {
          Text("Out of \(shortEvaluation.count) resolved shorter-horizon forecasts.")
        }
      }

      if let metrics = predictor.metrics, metrics.source == .rollingOrigin {
        Section {
          SubtitleCell(title: "AUC", subtitle: metrics.rollingSummary?.replacingOccurrences(of: "AUC ", with: "") ?? "N/A")
          SubtitleCell(title: "Brier (raw)", subtitle: metrics.rollingBrier.map({ String(format: "%0.3f", $0) }) ?? "N/A")
          SubtitleCell(title: "Log Loss", subtitle: metrics.rollingLogLoss.map({ String(format: "%0.3f", $0) }) ?? "N/A")
          SubtitleCell(title: "Folds", subtitle: metrics.rollingFoldCount.map({ "\($0)" }) ?? "N/A")
          SubtitleCell(title: "Positives / Clusters", subtitle: "\(metrics.rollingPositiveCount ?? 0) / \(metrics.rollingClusterCount ?? 0)")
          SubtitleCell(title: "Training Time", subtitle: metrics.trainingDuration.map({ String(format: "%0.0f s", $0) }) ?? "N/A")
          SubtitleCell(title: "Days / Episodes", subtitle: "\(metrics.trainingDayCount.map({ "\($0)" }) ?? "N/A") / \(metrics.episodeCount.map({ "\($0)" }) ?? "N/A")")
        } header: {
          Text("Rolling-origin (24h)")
        } footer: {
          Text("Every row scored by a model trained only on the days before it, with a 24-hour embargo. The AUC interval is an episode-cluster bootstrap; fewer than 10 positives or 3 episodes leaves the model unevaluated and uncalibrated.")
        }

        Section {
          Toggle("Personalized Candidate", isOn: $personalizationEnabled)
          SubtitleCell(title: "Status", subtitle: metrics.personalization?.statusDescription ?? (personalizationEnabled ? "Not evaluated yet" : "Off"))
        } header: {
          Text("Personalization")
        } footer: {
          Text("Your confident triggers from Insights get extra trend columns in a second model. It ships only when it beats the base model on the same folds by at least \(Int(PersonalizationSelection.promotionMargin * 100)) AUC points without worsening calibration. Takes effect on the next training run.")
        }

        Section {
          Toggle("Uncertainty Ensemble", isOn: $ensembleEnabled)
          SubtitleCell(title: "Members", subtitle: metrics.ensembleMemberCount.map({ "\($0)" }) ?? (ensembleEnabled ? "Not trained yet" : "Off"))
        } header: {
          Text("Forecast Range")
        } footer: {
          Text("\(TrainingConfiguration.regularized.ensembleMembers) extra 24h models, each fit on an episode-resampled copy of your history. The spread of their forecasts is the \"likely\" range; a range wider than \(Int(ForecastUncertainty.roughWidth * 100)) points or fewer than half the expected signals grades a forecast Rough. Takes effect on the next training run.")
        }
      }

      if let metrics = predictor.metrics {
        Section {
          if let accuracy = metrics.accuracy {
            SubtitleCell(title: "Validation Accuracy", subtitle: "\(String(format: "%0.1f%%", accuracy * 100.0)) (n=\(metrics.validationRowCount))")
          }
          if let brier = metrics.brier {
            SubtitleCell(title: "Validation Brier", subtitle: String(format: "%0.3f", brier))
          }
          SubtitleCell(title: "Calibrated", subtitle: metrics.isCalibrated ? "Yes" : (metrics.source == .rollingOrigin ? "No (too few out-of-fold rows)" : "No (validation slice too small)"))

          ForEach(metrics.calibrationBuckets, id: \.lowerBound) { bucket in
            SubtitleCell(
              title: String(format: "Bucket %0.0f%%+", bucket.lowerBound * 100.0),
              subtitle: String(format: "predicted %0.0f%%, observed %0.0f%% (n=%d)", bucket.meanPredicted * 100.0, bucket.observedRate * 100.0, bucket.count))
          }
        } header: {
          Text(metrics.source == .rollingOrigin ? "Out-of-fold (24h)" : "Validation (24h)")
        } footer: {
          if metrics.source == .rollingOrigin {
            Text("Calibrated accuracy and Brier over the pooled out-of-fold rows the calibration was fit on (trained \(metrics.trainedAt.formattedNonRelative())).")
          }
          else {
            Text("Measured on a held-out validation slice the model never trained on (trained \(metrics.trainedAt.formattedNonRelative())).")
          }
        }
      }

      if let shortMetrics = predictor.shortMetrics {
        Section {
          if let accuracy = shortMetrics.accuracy {
            SubtitleCell(title: "Validation Accuracy", subtitle: "\(String(format: "%0.1f%%", accuracy * 100.0)) (n=\(shortMetrics.validationRowCount))")
          }
          if let brier = shortMetrics.brier {
            SubtitleCell(title: "Validation Brier", subtitle: String(format: "%0.3f", brier))
          }
          SubtitleCell(title: "Calibrated", subtitle: shortMetrics.isCalibrated ? "Yes" : "No (validation slice too small)")
        } header: {
          Text(shortMetrics.source == .rollingOrigin ? "Out-of-fold (12h)" : "Validation (12h)")
        } footer: {
          Text(shortMetrics.source == .rollingOrigin
               ? "The shorter-horizon classifier over the same folds\(shortMetrics.rollingAUC.map({ String(format: " (AUC %0.2f)", $0) }) ?? "")."
               : "The shorter-horizon classifier, measured on the same held-out slice.")
        }
      }

      Section {
        AsyncButton("Train Models", mode: .afterContent, action: headacheManager.trainClassifiers)
      } footer: {
        Text("Models last trained \(predictor.modelUpdatedAt?.formattedNonRelative() ?? "N/A")")
      }
      
      Section {
        SubtitleCell(title: "Last Outlook", subtitle: debugPreferences.lastOutlookDate?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Next Outlook", subtitle: debugPreferences.nextOutlookDate?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Last Training", subtitle: debugPreferences.lastTrainingDate?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Next Training", subtitle: debugPreferences.nextTrainingDate?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Last Prediction", subtitle: debugPreferences.lastPredictionDate?.formattedNonRelative() ?? "N/A")
        SubtitleCell(title: "Next Prediction", subtitle: debugPreferences.nextPredictionDate?.formattedNonRelative() ?? "N/A")
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
        shortEvaluation = try await headacheManager.evaluation(horizonHours: 12)
        evaluationPoints = try await headacheManager.evaluationSeries()
      }
      catch {
        logError("Error evaluating models: \(error)")
      }

      do {
        outlookCounts = try await headacheManager.trainingDataOutlookCounts()
        contextLackingCount = try await headacheManager.trainingDataLackingContextCount()
      }
      catch {
        logError("Error counting training data: \(error)")
      }

      snapshot = await headacheManager.locationWeatherSnapshot()
    }
    .fileExporter(isPresented: $showingExportDocument, document: BackupDocument(url: exportURL), contentType: UTType(filenameExtension: "sqlite")!, onCompletion: exportDocumentAction)
    .fileImporter(isPresented: $showingImportDocument, allowedContentTypes: [UTType(filenameExtension: "sqlite")!], onCompletion: importDocumentAction)
  }
}

class BackupDocument: FileDocument {
  // Only the database is imported (restore), so reading stays `.database`.
  static var readableContentTypes: [UTType] {
    [UTType.database]
  }

  // This document wraps whatever file `url` points at, so it backs three
  // exporters: the `.sqlite` backup (DebugSettingsView) and the clinician
  // PDF report + CSV log (ExportView). `fileExporter`'s `contentType:` must be
  // one of these, or the panel mislabels/rejects the PDF and CSV exports.
  static var writableContentTypes: [UTType] {
    [UTType.database, UTType.pdf, UTType.commaSeparatedText]
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
