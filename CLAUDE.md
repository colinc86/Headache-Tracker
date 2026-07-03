# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A SwiftUI iOS app that logs headaches and uses on-device CreateML/CoreML to predict their **outlook** (whether one is coming), **severity**, **onset** time, and **duration** from weather, HealthKit, and time-of-day signals. There is also a WidgetKit extension. No backend — everything (data, training, inference) runs on device.

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

The unit/UI test targets (`Headache TrackerTests`, `Headache TrackerUITests`) are currently Xcode template stubs — there is effectively no real test coverage. Don't assume tests validate behavior.

Swift 5, iOS deployment target 17.0 (the widget/some configs still list 15.2).

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
- `Refresher` — registers and schedules `BGTaskScheduler` background tasks for periodic training, prediction, and daily outlook; owns the `AlertManager` for notifications.

These (plus `HeadacheManager.predictor` and `.healthKitManager`) are injected as `@environmentObject`s at the root in `Headache_TrackerApp.body`. Background work is scheduled on `willResignActive` and cancelled on `didBecomeActive`.

### HeadacheManager — the coordinator

`Shared/Models/HeadacheManager.swift` is where most domain logic lives. It composes `WeatherManager`, `HealthKitManager`, `LocationManager`, and the `Predictor`, and exposes `async`/`throws` methods for everything: changing the current severity, resolving headaches, CRUD on headaches/severities/tags, building model input, creating training data, training, predicting, and evaluating prediction accuracy.

A typical write (e.g. `changeSeverity`) both mutates Core Data **and** mirrors the change to HealthKit, the shared widget defaults, and the ML training pipeline — keep all of those in sync when editing these methods.

### Persistence

Core Data via the external `DataController` package (`DataController.shared`). All writes go through `DataController.shared.performInBackground(saveOnComplete:)` with a background context. Entities (model `Headache_Tracker 1.8`, the current version): `Headache`, `Severity`, `HealthData`, `Location`, `WeatherData`, `Tag`, `TrainingData`, `Evaluation`.

**Naming collision to watch for:** `Headache.Severity` is a Swift `typealias` for HealthKit's `HKCategoryValueSeverity` (an enum of severity *levels*), while the Core Data entity named `Severity` is represented by the class **`SeverityState`** (a logged severity *interval* on a headache). They are different things despite the overlapping name. Core Data extensions live under `Shared/Models/Extensions/Core Data/`.

All entity classes are Xcode-codegen'd except `Headache` and `TrainingData` (codegen "category"), whose class definitions are hand-written in `Shared/Models/Core Data/`.

### The ML prediction pipeline

Four independent models, trained and run together (`Predictor.ModelType`):

- `outlookClassifier` / `severityClassifier` — `MLBoostedTreeClassifier`
- `onsetRegressor` / `durationRegressor` — `MLBoostedTreeRegressor`

Flow:

1. **Input assembly** — `HeadacheManager.predictorInput(atDate:inWidget:)` gathers location → weather → HealthKit data into a `ModelInput` (`Shared/Models/Prediction/ModelInput.swift`).
2. **Feature expansion** — `ModelInput.fullInput()` produces an `InputUnion` (an `MLFeatureProvider` that merges four sub-providers: `ControlledUserInput`, `EnvironmentalInput`, `ChronologicalInput`, `UncontrolledUserInput` in `Prediction/Inputs/`). The four `Prediction/Outputs/*.swift` types decode each model's prediction.
3. **Training data** — user actions persist `TrainingData` rows. `TrainingInput` (`Prediction/TrainingInput.swift`) turns them into four `MLDataTable`s, including class balancing via a hand-rolled **SMOTE** (k-NN synthetic oversampling using `Accelerate`/`Surge`).
4. **Train** — `Predictor.train(_:)` trains all four models on `modelQueue`, writes `.mlmodel`, compiles to `.mlmodelc`, and atomically swaps them into the app-group `models/` directory.
5. **Predict** — `Predictor.predict(_:inWidget:)` loads compiled models if stale (`needsLoading()`), runs all four, builds a `PredictionOutput`, publishes it, and stores it in shared `UserDefaults` for the widget.
6. **Evaluate** — `evaluatePrediction` records whether outlook/severity predictions matched reality into `Evaluation` rows for an accuracy readout.

Compiled models are versioned by file modification date; `TrainingData` carries `Constants.trainingDataVersion` / `trainingDataWeatherVersion`, and `upgradeTrainingData()` back-fills HealthKit/weather data when those versions change.

### Cross-process sharing (app ↔ widget)

The app and widget communicate through the **app group** `group.com.cnc.Headache-Tracker.contents` (`Constants.appGroupIdentifier`): compiled ML models live in that container's `models/` dir, and the current severity/prediction are written to shared `UserDefaults` via `Preferences.shared` so the widgets can render without re-running inference. URL scheme `myheadache://severity?rawValue=…` lets widgets deep-link severity changes.

### Preferences

`Shared/Models/Preferences/Preferences.swift` is a single struct namespacing all `@AppStorage`/`UserDefaults`-backed settings into sub-structs (`general`, `headaches`, `health`, `notifications`, `predictors`, `shared`, …), each with nested `Keys` and `Defaults`. Add new settings as a key + default inside the relevant sub-struct rather than reaching for `UserDefaults` directly.

## Dependencies

Remote SPM packages: Alamofire, CocoaLumberjack, Surge (the math/SMOTE), swiftui-shapes, IrregularGradient, swift-log, plus the author's own **`ApplicationKey`** (obfuscates string keys — used for queue labels and background-task identifiers) and **`DataController`** (the Core Data stack). There is no local logging backend wired up: `Shared/Models/Logging/Logger.swift` `logDebug`/`logError`/etc. currently just `print` (the CocoaLumberjack calls are commented out).

## Conventions

- 2-space indentation; `// MARK:` extensions group methods by concern, and most types are split across multiple `extension` blocks.
- Domain operations are `async throws`; errors conform to `CustomStringConvertible` (e.g. `HeadacheManager.HeadacheError`) for user-facing messages.
- Heavy ML work runs on dedicated `DispatchQueue`s (`modelQueue`, `trainingQueue`) bridged to `async` with `withCheckedThrowingContinuation`.
