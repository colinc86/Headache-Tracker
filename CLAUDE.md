# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A SwiftUI iOS app that logs headaches (plus medications and daily trigger exposures) and uses on-device CreateML/CoreML to predict a single calibrated **risk of a headache within the next 24 hours** from weather, HealthKit, and time-of-day signals. There is also a WidgetKit extension (two widgets + a Live Activity). No backend — everything (data, training, inference) runs on device; optional CloudKit sync (default off) mirrors user data only to the user's private database.

## Build, run, test

Open `Headache Tracker.xcodeproj` in Xcode (there is no `.xcworkspace`; Swift Package dependencies are resolved by Xcode). Schemes:

- **Headache Tracker** — main app scheme.
- **Headache Tracker Preview** — same app built with the `Preview` build configuration, used for SwiftUI previews / preview data.
- **Headache Tracker WidgetExtension** — the widgets.

Build configurations are `Debug`, `Preview`, and `Release`. If you invoke `xcodebuild` without `-scheme`, it defaults to `Release`.

Command line:

```sh
# Build the app
xcodebuild -project "Headache Tracker.xcodeproj" -scheme "Headache Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run all tests (unit + UI)
xcodebuild -project "Headache Tracker.xcodeproj" -scheme "Headache Tracker" \
  -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run a single test
xcodebuild ... test -only-testing:"Headache TrackerTests/Headache_TrackerTests/<testMethod>"
```

`Headache TrackerTests` contains real unit tests (headache interval invariants, label derivation, statistics math, correlation math/engine, calibration, brief builder, exposures/medications, CSV escaping) running against an in-memory Core Data store; run them before committing model-layer changes. `Headache TrackerUITests` is still a template stub.

Swift 5, iOS deployment target 17.0 across all targets.

## The simulator vs. device split (critical)

**CreateML is not available on the iOS Simulator.** Every file that trains or instantiates ML models is wrapped in `#if !targetEnvironment(simulator)` / `#else` / `#endif`, and there is a parallel **stub** implementation for the simulator. The most important pair:

- `Shared/Models/Prediction/Predictor.swift` — real `Predictor` (device). Guarded with `#if !targetEnvironment(simulator)`.
- `Shared/Models/Prediction/TestPredictor.swift` — stub `Predictor` with the same public API (simulator). Guarded with `#if targetEnvironment(simulator)`.

Both define a class named `Predictor`; exactly one compiles depending on the target. The same dual-compilation pattern applies to `Model.swift`, `TrainingInput.swift`, `MLDataTable+Extensions.swift`, and the four `Outputs/*.swift` files.

**When changing the `Predictor` public surface, update both `Predictor.swift` and `TestPredictor.swift`**, or simulator builds break. Anything ML-related can only be exercised on a real device.

## Architecture

### Layout

- `Shared/` — model layer, ML, Core Data, extensions, and cross-target SwiftUI views. Shared between the app and the widget.
- `Headache Tracker/` — the app: SwiftUI `Views/` (organized into `Content Views/`, `Cards/`, `Cells/`, `Graphs/`), app lifecycle in `Models/App/`, background scheduling in `Models/Refresher/`, notifications in `Models/Alerts/`.
- `Headache Tracker Widget/` — two widgets, `Outlook/` and `Severity/`, each with the standard WidgetKit Provider/Content/View split.

### App lifecycle / object graph

`Headache_TrackerApp` (`@main`) installs `AppDelegate` via `@UIApplicationDelegateAdaptor`. `AppDelegate` owns the two root objects:

- `HeadacheManager` — the central coordinator (see below).
- `Refresher` — registers and schedules two `BGTaskScheduler` tasks: an hourly app-refresh (prediction + the daily outlook alert when due — one identifier, because iOS budgets refresh opportunities per app) and a daily processing task for training (requires external power); owns the `AlertManager` for notifications. Background task handlers complete exactly once via `TaskCompletionGuard`.

These (plus `HeadacheManager.predictor` and `.healthKitManager`) are injected as `@environmentObject`s at the root in `Headache_TrackerApp.body`. Background work is scheduled on `willResignActive` and cancelled on `didBecomeActive`.

### HeadacheManager — the coordinator

`Shared/Models/HeadacheManager.swift` is where most domain logic lives. It composes `WeatherManager`, `HealthKitManager`, `LocationManager`, and the `Predictor`, and exposes `async`/`throws` methods for everything: changing the current severity, resolving headaches, CRUD on headaches/severities/tags, building model input, creating training data, training, predicting, and evaluating prediction accuracy.

A typical write (e.g. `changeSeverity`) both mutates Core Data **and** mirrors the change to HealthKit, the shared widget defaults, and the ML training pipeline — keep all of those in sync when editing these methods.

### Persistence

Core Data via the external `DataController` package (`DataController.shared`). All writes go through `DataController.shared.performInBackground(saveOnComplete:)`, which runs every block on a single long-lived serial write context that saves directly to the store; the view context auto-merges those saves. **Note:** the project currently pins DataController to the local clone at `../../Packages/DataController` (v1.4.0, tagged locally) — push that repo's `main` + tags to GitHub and restore the `https://github.com/colinc86/DataController.git` URL in the project when publishing. Entities (model `Headache_Tracker 2.1`, the current version): `Headache`, `Severity`, `HealthData`, `Location`, `WeatherData`, `Tag`, `TrainingData`, `Evaluation`, `MedicationEntry`, `Exposure`. Model 2.1 defines two configurations for the optional store split: **Cloud** (Headache, Severity, Tag, MedicationEntry, Exposure) and **Local** (TrainingData, HealthData, WeatherData, Location, Evaluation); relationships must never cross that boundary (the old Severity↔TrainingData provenance link was removed for this). `HealthData.presentMetrics`/`WeatherData.presentFields` are presence bitmasks — an unset bit means "no reading", distinct from a stored zero; always gate reads on them.

Domain invariant, enforced by `HeadacheManager` and a launch-time repair pass: a headache is unresolved iff its last severity has `endTime == nil`, and at most one headache is unresolved at a time.

**Naming collision to watch for:** `Headache.Severity` is a Swift `typealias` for HealthKit's `HKCategoryValueSeverity` (an enum of severity *levels*), while the Core Data entity named `Severity` is represented by the class **`SeverityState`** (a logged severity *interval* on a headache). They are different things despite the overlapping name. Core Data extensions live under `Shared/Models/Extensions/Core Data/`.

All entity classes are Xcode-codegen'd except `Headache` and `TrainingData` (codegen "category"), whose class definitions are hand-written in `Shared/Models/Core Data/`.

### The ML prediction pipeline

One binary `MLBoostedTreeClassifier` ("Risk": does a headache start within the rolling 24h window), with hand-rolled Platt calibration (`Calibration.swift`) fit on the chronologically held-out validation slice. The public surface is `RiskPrediction` (probability, tier low/elevated/high at 0.30/0.60, topFactors) and `RiskOutlook` (forecast vs. active headache) — see `Shared/Models/Prediction/RiskPrediction.swift`. In-headache rows are excluded from training and inference. `RiskBriefBuilder` turns the prediction + cached insights baselines into the "morning brief" reasons shown in notifications and the Why card.

Flow:

1. **Input assembly** — `HeadacheManager.predictorInput(atDate:inWidget:)` gathers location → weather → HealthKit data into a `ModelInput` (`Shared/Models/Prediction/ModelInput.swift`). HealthKit reads use per-metric sampling windows (`HealthKitData.window(endingAt:)`); metrics with no samples are *absent* from the dictionary, never zero-filled.
2. **Feature expansion** — `ModelInput.fullInput()` produces an `InputUnion` (an `MLFeatureProvider` that merges four sub-providers: `ControlledUserInput`, `EnvironmentalInput`, `ChronologicalInput`, `UncontrolledUserInput` in `Prediction/Inputs/`). Time-of-day/weekday are sin/cos pairs; station and device pressure are separate features. The four `Prediction/Outputs/*.swift` types decode each model's prediction. When the feature set changes, bump `Constants.modelSchemaVersion` — a launch check resets models and evaluations.
3. **Training data & labels** — user actions and hourly refreshes persist `TrainingData` rows. Labels (outlook, severity, onset/duration targets) are **derived at training time** from headache episode intervals (`deriveLabels(from:)` in `TrainingData+Extensions.swift`, rolling 24h outlook window); the `severity` relationship is provenance only. `TrainingInput` (`Prediction/TrainingInput.swift`) splits chronologically 80/20, computes per-feature medians from the training slice (`FeatureMedians`, persisted beside the models and reused at inference), imputes, and balances classifier classes by capped duplication.
4. **Train** — `Predictor.train(_:)` trains the classifier on `modelQueue`, scores the held-out rows through the freshly compiled model (CreateML exposes no per-row training-time probabilities), fits the Platt calibration, computes accuracy/Brier/calibration buckets (`ModelMetrics`) and permutation importances, then swaps the compiled model plus `medians/metrics/importances/calibration/schemaVersion.json` into the app-group `models/` directory.
5. **Predict** — `Predictor.predict(_:inWidget:)` loads the compiled model if stale, median-imputes, applies the calibration, builds a `RiskPrediction`, publishes it, and stores it in shared `UserDefaults` (`Preferences.Shared.currentRisk`) for the widget.
6. **Evaluate** — `evaluatePrediction` writes *pending* `Evaluation` rows with the calibrated probability; `resolveEvaluations()` scores them after the 24h window; `evaluation()` reports observed accuracy + Brier.

Compiled models are versioned by file modification date; `TrainingData` carries `Constants.trainingDataVersion` / `trainingDataWeatherVersion`, and `upgradeTrainingData()` back-fills HealthKit/weather data when those versions change.

### The correlation engine (Insights)

`Shared/Models/Statistics/Correlation/` computes transparent per-feature associations between ~30 health/weather/exposure signals and headaches — point-biserial vs. onset-within-6/12/24/48h (over personal-baseline rolling z-scores when enough history, winsorized at |z| = 6) and Spearman vs. severity, with circular-shift permutation p-values, Benjamini–Hochberg FDR, and a confounder pass that annotates findings largely explained by a co-correlated feature (first-order partial correlation). Pure Surge math, simulator-safe, gated on n ≥ 30 pairs and ≥ 10 events. Logged `Exposure` rows merge into the sample matrix as trailing-24h counts (only after the user's first check-in — absence before logging began is unknown, not zero; custom kinds are recorded but not correlated). Reports (`InsightsReport`, with per-feature 14-day baselines and a schema version) are cached as JSON in the app group (`InsightsStore`); staleness tracks row count, exposure count, age, and schema version. The UI is `InsightsView`/`TriggerDetailView` (Swift Charts) plus a top-3 section in the Analyze tab.

### Cross-process sharing (app ↔ widget)

The app and widget communicate through the **app group** `group.com.cnc.Headache-Tracker.contents` (`Constants.appGroupIdentifier`): compiled ML models (plus sidecars) and the cached insights report live in that container, and the current severity/risk are written to shared `UserDefaults` via `Preferences.shared` so the widgets can render without re-running inference. The color theme and measurement system also live in the shared suite (`@AppStorage(key, store: .shared)`). The severity widget logs via `LogSeverityIntent` (a `LiveActivityIntent`, so it executes the full `changeSeverity` flow in the app process); `myheadache://severity?rawValue=…` remains for external deep links. `HeadacheLiveActivity` shows an in-progress headache on the lock screen/Dynamic Island; `LiveActivityManager.reconcile` (app-only) is the single sync point. The widget target defines `SWIFT_ACTIVE_COMPILATION_CONDITIONS = WIDGET_EXTENSION` to exclude app-only calls from shared files. `AlertManager`/`HeadacheAlertRequest` live in `Shared/Models/Alerts/` (both targets); notification categories/actions and tap routing (`AlertDelegate`, `Router`) are app-side.

### CloudKit sync (default off)

`Preferences.Sync.enabled` (shared suite) is read once at store setup. Off: one combined store, exactly as pre-sync. On: two stores — the original file becomes the Local store; user data lives in `Headache_Tracker-cloud.sqlite` mirrored by `NSPersistentCloudKitContainer` (container `iCloud.com.cnc.Headache-Tracker`, app process only; the widget gets history tracking without mirroring). `CloudMigrator` copies the user-data graph into the cloud store once on first sync-enabled launch. Remote changes trigger repair + tag dedup + shared-severity refresh + history purge (`AppDelegate.observeRemoteChanges`). Enabling history tracking is one-way; database restore is disabled while syncing.

### Preferences

`Shared/Models/Preferences/Preferences.swift` is a single struct namespacing all `@AppStorage`/`UserDefaults`-backed settings into sub-structs (`general`, `headaches`, `health`, `notifications`, `predictors`, `shared`, …), each with nested `Keys` and `Defaults`. Add new settings as a key + default inside the relevant sub-struct rather than reaching for `UserDefaults` directly.

## Dependencies

Remote SPM packages: Alamofire (no longer referenced by any source; safe to drop from the project), CocoaLumberjack, Surge (statistics/correlation math), swiftui-shapes, IrregularGradient, swift-log, plus the author's own **`ApplicationKey`** (obfuscates string keys — used for queue labels and background-task identifiers) and **`DataController`** (the Core Data stack). There is no local logging backend wired up: `Shared/Models/Logging/Logger.swift` `logDebug`/`logError`/etc. currently just `print` (the CocoaLumberjack calls are commented out).

## Conventions

- 2-space indentation; `// MARK:` extensions group methods by concern, and most types are split across multiple `extension` blocks.
- Domain operations are `async throws`; errors conform to `CustomStringConvertible` (e.g. `HeadacheManager.HeadacheError`) for user-facing messages.
- Heavy ML work runs on dedicated `DispatchQueue`s (`modelQueue`, `trainingQueue`) bridged to `async` with `withCheckedThrowingContinuation`.
