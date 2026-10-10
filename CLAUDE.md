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

Swift 5. iOS deployment target 26.0 (app, widget, tests) so the app can use Apple's on-device Foundation Models; the watch targets stay on watchOS 10. Simulators must run iOS 26 (e.g. iPhone 17).

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

Core Data via the external `DataController` package (`DataController.shared`). All writes go through `DataController.shared.performInBackground(saveOnComplete:)`, which runs every block on a single long-lived serial write context that saves directly to the store; the view context auto-merges those saves. **Note:** the project currently pins DataController to the local clone at `../../Packages/DataController` (v1.4.0, tagged locally) — push that repo's `main` + tags to GitHub and restore the `https://github.com/colinc86/DataController.git` URL in the project when publishing. Entities (model `Headache_Tracker 2.5`, the current version): `Headache`, `Severity`, `HealthData`, `Location`, `WeatherData`, `ContextData`, `Tag`, `TrainingData`, `Evaluation`, `MedicationEntry`. Two configurations for the optional store split: **Cloud** (Headache, Severity, Tag, MedicationEntry) and **Local** (TrainingData, HealthData, WeatherData, ContextData, Location, Evaluation); relationships must never cross that boundary (the old Severity↔TrainingData provenance link was removed for this). `HealthData.presentMetrics`/`WeatherData.presentFields`/`ContextData.presentMetrics`+`presentRanges` are presence bitmasks — an unset bit means "no reading", distinct from a stored zero; always gate reads on them. Model 2.5 added `TrainingData.source` (`TrainingDataSource`: userAction / foreground / background / backdated), `Evaluation.actualOutcomeRaw` (tri-state; `Evaluation.actualOutcome` reconstructs older rows), and `ContextData` (15 metrics × 5 trailing-window statistics, see step 1 below).

Domain invariant, enforced by `HeadacheManager` and a launch-time repair pass: a headache is unresolved iff its last severity has `endTime == nil`, and at most one headache is unresolved at a time.

**Naming collision to watch for:** `Headache.Severity` is a Swift `typealias` for HealthKit's `HKCategoryValueSeverity` (an enum of severity *levels*), while the Core Data entity named `Severity` is represented by the class **`SeverityState`** (a logged severity *interval* on a headache). They are different things despite the overlapping name. Core Data extensions live under `Shared/Models/Extensions/Core Data/`.

All entity classes are Xcode-codegen'd except `Headache` and `TrainingData` (codegen "category"), whose class definitions are hand-written in `Shared/Models/Core Data/`.

### The ML prediction pipeline

One binary `MLBoostedTreeClassifier` ("Risk": does a headache start within the rolling 24h window), with hand-rolled Platt calibration (`Calibration.swift`) fit on the pooled out-of-fold scores of the rolling-origin evaluation. The public surface is `RiskPrediction` (probability, tier low/elevated/high at 0.30/0.60, topFactors) and `RiskOutlook` (forecast vs. active headache) — see `Shared/Models/Prediction/RiskPrediction.swift`. In-headache rows are excluded from training and inference. `RiskBriefBuilder` turns the prediction + cached insights baselines into the "morning brief" reasons shown in notifications; `RiskDriver.make` (app) merges the signed `contributions` with those value-vs-usual deviations for the Track tab's drivers strip.

Flow:

1. **Input assembly** — `HeadacheManager.predictorInput(atDate:inWidget:)` gathers location → weather → HealthKit data into a `ModelInput` (`Shared/Models/Prediction/ModelInput.swift`). HealthKit reads use per-metric sampling windows (`HealthKitData.window(endingAt:)`); metrics with no samples are *absent* from the dictionary, never zero-filled. **Temporal context** (`WindowStatistics`): for the 12 `HealthKitData.windowMetrics` and 3 station weather fields, `HealthKitManager.readWindowStatistics` (one hourly `HKStatisticsCollectionQuery` per metric) and `Weather.windowStatistics` (from the 72h hourly WeatherKit fetch) compute 24h mean/delta, 48h/72h range, and 6h delta over **fixed clock windows**, stored per row in `ContextData`. Never derive these from stored row spacing: rows are logged when the app is used, usage tracks headaches, and row density alone predicts onsets (AUC 0.72 in the Sept 2026 study).
2. **Feature expansion** — `ModelInput.fullInput()` produces an `InputUnion` (an `MLFeatureProvider` that merges the sub-providers in `Prediction/Inputs/`: `ControlledUserInput`, `EnvironmentalInput`, `ChronologicalInput`, `UncontrolledUserInput`, `AutonomicBaselineInput` (causal 14-day z-scores/slopes), `TemporalContextInput` (base columns "<Metric> 24h Delta" / "48h Range" for every window metric; extended "24h Mean" / "72h Range" / "6h Delta" only for `ModelInput.personalizedFeatures`)). Time-of-day/weekday are sin/cos pairs; station and device pressure are separate features. Column names extend the raw column so `CorrelationFeature.matching(mlFeatureName:)` folds them onto their feature. When the feature set changes, bump `Constants.modelSchemaVersion` — a launch check resets models and evaluations.
3. **Training data & labels** — `TrainingData` rows are sampled on a clock, not usage: the hourly background refresh always tries (`.background`), the app foreground path creates one when the newest row is over an hour old (`.foreground`), severity changes/resolves/"No Headache" create one (`.userAction`), and back-logged headaches write past-dated rows (`.backdated`). `HeadacheManager.createTrainingData(from:source:)` drops any non-backdated row within 30 minutes of an existing one. Labels are **derived at training time** from headache episode intervals (`deriveLabels(from:)` in `TrainingData+Extensions.swift`, rolling 24h window). `TrainingInput` (`Prediction/TrainingInput.swift`) sorts, attaches baseline features, computes all-rows medians (`FeatureMedians`, persisted beside the models), builds a `RollingOriginPlan`, and builds per-slice tables on demand (`table(for:medians:horizon:balanced:personalized:)`, capped-duplication balancing).
4. **Train** — `Predictor.train(_:)` on `modelQueue` with `TrainingConfiguration.regularized` (depth 3, 150 trees, step 0.05, subsampled; CreateML's defaults overfit this data): (a) rolling-origin evaluation — each fold trains on the prefix ending 24h before its day-block and scores the block in memory via `Model(model: classifier.model)`, pooled into `RollingOriginResult` (`rolling.json`, episode-cluster bootstrap CI, permutation importances from the last fold); (b) **candidate-and-promote personalization** — when `Preferences.Debug.personalizationEnabled`, each fold asks `CorrelationEngine` (over that fold's prefix only) for confident, non-confounded onset features (`PersonalizationSelection.candidates`), a second variant carries their extended columns, and `PersonalizationSelection.decide` promotes it only on ΔAUC ≥ 0.02 with a no-worse Brier and a supportive paired bootstrap (`personalization.json`, `rollingPersonalized.json`); (c) Platt calibration and `ModelMetrics` from the winning variant's out-of-fold scores; (d) the 12h model follows the same folds; (d′) **bagged ensemble** — when `Preferences.Debug.ensembleEnabled` and the rolling result is usable, `TrainingConfiguration.ensembleMembers` (6) extra 24h fits on episode-cluster resamples of all rows (`ClassificationMetrics.clusterResamples` over `ModelInput.labelCluster()`: next-onset date, else the row's day), each with its own seed and a cancellation gate, kept in memory; (e) the last cancellation gate, then final fits on **all rows** for both horizons, the members as `rcb0…rcbN.mlmodelc` + `ensemble.json`, then every sidecar (`medians/baselines/metrics/importances/calibration/rolling/personalization/schemaVersion.json`; `metrics.json` also carries `trainingDayCount`/`episodeCount`/`ensembleMemberCount`) written together into the app-group `models/` directory. Members load best-effort and all-or-nothing.
5. **Predict** — `Predictor.predict(_:inWidget:)` loads the compiled model if stale, applies the persisted personalization set, records `InputCoverage` (`FeatureMedians.coverage(of:enabled:)`: expected = enabled metrics with a median + weather), median-imputes, applies the calibration, scores the ensemble members through the same calibration into a `RiskInterval` (`ForecastUncertainty.interval`: 10th–90th percentile widened to include the point), builds a `RiskPrediction` (`interval`/`coverage`/`modelAccuracy` optional for back-compat; `confidence` = steady/fair/rough from width and coverage), publishes it, and stores it in shared `UserDefaults` (`Preferences.Shared.currentRisk`) for the widget. The probability is a calibrated frequency ("of 100 days like today…"), never a confidence; the range and grade are the per-forecast uncertainty. `Predictor.scores(for:includeInterval:)` scores arbitrary inputs on both horizons without publishing (one `modelQueue` hop per batch; `probabilities(for:)` forwards to it) — the what-if explorer's call; only its header asks for the interval. The explorer lives in `Headache Tracker/Views/Content Views/WhatIf/` on a pure, tested `WhatIfScenario` (dimensions, presets from `InsightsStore` baselines, snap detent, interpolation, shared y-domain); its curves pin `chartXScale` to the slider range and inset the plot by the slider thumb radius so markers sit under the thumb.
6. **Evaluate** — `recordEvaluation(for:)` writes *pending* `Evaluation` rows from both the app path and the background refresh (deduped per horizon within 30 minutes); `resolveEvaluations()` stores the actual outcome after the window; `evaluation()` / `evaluationSeries()` feed the Debug "Observed" sections, the Profile-tab `ModelAccuracyCard` (`ProspectiveAccuracy`) and reliability card, and the Today-card milestone.

Compiled models are versioned by file modification date; `TrainingData` carries `Constants.trainingDataVersion` / `trainingDataWeatherVersion` / `trainingDataContextVersion`, and `upgradeTrainingData()` back-fills HealthKit/weather data and the window context (`backFillTrainingDataContext`: chunked hourly HealthKit series and clustered WeatherKit history, never per-row queries) when those versions change.

### The correlation engine (Insights)

`Shared/Models/Statistics/Correlation/` computes transparent per-feature associations between ~30 health/weather/exposure signals and headaches — point-biserial vs. onset-within-6/12/24/48h (over personal-baseline rolling z-scores when enough history, winsorized at |z| = 6) and Spearman vs. severity, with circular-shift permutation p-values, Benjamini–Hochberg FDR, and a confounder pass that annotates findings largely explained by a co-correlated feature (first-order partial correlation). Pure Surge math, simulator-safe, gated on n ≥ 30 pairs and ≥ 10 events. Logged `Exposure` rows merge into the sample matrix as trailing-24h counts (only after the user's first check-in — absence before logging began is unknown, not zero; custom kinds are recorded but not correlated). Reports (`InsightsReport`, with per-feature 14-day baselines and a schema version) are cached as JSON in the app group (`InsightsStore`); staleness tracks row count, exposure count, age, and schema version. The UI is the Profile tab's inline trigger rows (`ProfileTriggerRow`, sharing `TriggerSeriesChart` with `TriggerDetailView`) and its signature glyph built from `domainProfile`.

### Cross-process sharing (app ↔ widget)

The app and widget communicate through the **app group** `group.com.cnc.Headache-Tracker.contents` (`Constants.appGroupIdentifier`): compiled ML models (plus sidecars) and the cached insights report live in that container, and the current severity/risk are written to shared `UserDefaults` via `Preferences.shared` so the widgets can render without re-running inference. The color theme and measurement system also live in the shared suite (`@AppStorage(key, store: .shared)`). **Risk widgets** (Outlook small/medium/large, Twin Ring small + Lock Screen circular/inline, Horizon medium/large, Signals medium/large, Risk Clock medium; kinds in `Constants.Widgets.riskKinds`) all use one `RiskTimelineProvider` (`Headache Tracker Widget/Shared/`) that builds a `RiskSnapshot` (`Shared/Models/Prediction/RiskSnapshot.swift`: 12h/24h probabilities and tiers, freshness fresh/aging/stale, signed contributions with a `topFactors` fallback, 48h logged history with the live forecast appended, brief reasons, trajectory, peak window) via `WidgetDataSource` (shared defaults + two read-only Core Data fetches — **never** `HeadacheManager`, sensors, WeatherKit, or the model in the widget process) and emits half-hourly entries for six hours. `WidgetReloader.reloadRisk()` runs from `setCurrentRisk`/`setCurrentSeverity`. Widget views never use `Card`; conventions and the shared building blocks (`RiskRingGauge`, `RiskSparklineStatic`, `ContributionRow`, `RiskAgeLabel`, `RiskWidgetState`, `RiskFormat`) live in `Headache Tracker Widget/Shared/`. The forecast's range draws as a translucent band on `RiskRing` (`band:`), a whisker on the Horizon 24h bar, and "Likely 44–66%" captions; the grade is `ForecastConfidenceBadge` (`Shared/Views/`, app + widget, `monochrome:` for tinted rendering), always beside a headline accuracy (`ForecastAccuracy.headline`: observed over ≥ 30 resolved forecasts via `WidgetDataSource.observedAccuracy()`/`HeadacheManager.evaluation()`, else the forecast's carried out-of-fold `modelAccuracy`). Widget taps deep-link via `myheadache://outlook|signals|insights` (`SceneDelegate.handle` → `Router.routeToTrack()/routeToProfile(_:)`; `ProfileView` scrolls to its triggers for `.insights` and presents Signals for `.signals`). The severity widget logs via `LogSeverityIntent` (a `LiveActivityIntent`, so it executes the full `changeSeverity` flow in the app process); `myheadache://severity?rawValue=…` remains for external deep links. `HeadacheLiveActivity` shows an in-progress headache on the lock screen/Dynamic Island; `LiveActivityManager.reconcile` (app-only) is the single sync point. The widget target defines `SWIFT_ACTIVE_COMPILATION_CONDITIONS = WIDGET_EXTENSION` to exclude app-only calls from shared files. `AlertManager`/`HeadacheAlertRequest` live in `Shared/Models/Alerts/` (both targets); notification categories/actions and tap routing (`AlertDelegate`, `Router`) are app-side.

### Tabs and written summaries

Tabs: **Track** (`CurrentHeadacheView` + `Headache Tracker/Views/Track/`: `TrackHeroView` orb + written summary + `RiskRibbon` (48h of logged forecasts flowing into the 24h window as a plateau with its range band), `DriversStrip`, `TodayCard` (`StreakSummary`: streak ring + 14-day dots), `ActiveHeadacheHero` during a headache, and `SeverityLogBar` pinned in `safeAreaInset(edge: .bottom)` for one-tap logging/resolve), **Profile** (`Headache Tracker/Views/Profile/`: `SignatureGlyph` petals per `SignalDomain`, portrait, inline triggers, `RhythmClock`, `HeadacheShapeChart`, medications, month, forecast accuracy/reliability; data from `ProfileAnalytics` (pure) via `HeadacheManager.profileSource()`), **Headaches** (`HeadacheStatsSections` overview tiles + optional charts above the list, period menu in the toolbar), Settings.

Written summaries (`Headache Tracker/Models/Summaries/`): pure fact sheets (`RiskFacts`, `ProfileFacts`, already human-formatted) → `TemplateSummaryWriter` (deterministic, always available) or `AppleIntelligenceSummaryWriter` (`FoundationModels`, guided generation with `@Generable`, iOS 26) → `SummaryValidator` (rejects numbers or signals absent from the facts, advice/diagnosis phrasing, length) → `SummaryStore` (app-group `summaries.json`, keyed by the facts' SHA-256). `SummaryService` (root `@EnvironmentObject`) serves the template instantly and swaps in the model's rewrite; `Preferences.General.aiSummaries` gates it, Settings explains unavailability. The model never sees raw data and never computes numbers. Under `--uitest-seed` a `UITestSummaryWriter` marks template prose as generated (the simulator has no model).

### CloudKit sync (default off)

`Preferences.Sync.enabled` (shared suite) is read once at store setup. Off: one combined store, exactly as pre-sync. On: two stores — the original file becomes the Local store; user data lives in `Headache_Tracker-cloud.sqlite` mirrored by `NSPersistentCloudKitContainer` (container `iCloud.com.cnc.Headache-Tracker`, app process only; the widget gets history tracking without mirroring). `CloudMigrator` copies the user-data graph into the cloud store once on first sync-enabled launch. Remote changes trigger repair + tag dedup + shared-severity refresh + history purge (`AppDelegate.observeRemoteChanges`). Enabling history tracking is one-way; database restore is disabled while syncing.

### Preferences

`Shared/Models/Preferences/Preferences.swift` is a single struct namespacing all `@AppStorage`/`UserDefaults`-backed settings into sub-structs (`general`, `headaches`, `health`, `notifications`, `predictors`, `shared`, …), each with nested `Keys` and `Defaults`. Add new settings as a key + default inside the relevant sub-struct rather than reaching for `UserDefaults` directly.

## Dependencies

Remote SPM packages: Alamofire (no longer referenced by any source; safe to drop from the project), CocoaLumberjack, Surge (statistics/correlation math), swiftui-shapes, IrregularGradient, swift-log, plus the author's own **`ApplicationKey`** (obfuscates string keys — used for queue labels and background-task identifiers) and **`DataController`** (the Core Data stack). There is no local logging backend wired up: `Shared/Models/Logging/Logger.swift` `logDebug`/`logError`/etc. currently just `print` (the CocoaLumberjack calls are commented out).

## Conventions

- 2-space indentation; `// MARK:` extensions group methods by concern, and most types are split across multiple `extension` blocks.
- Domain operations are `async throws`; errors conform to `CustomStringConvertible` (e.g. `HeadacheManager.HeadacheError`) for user-facing messages.
- Heavy ML work runs on the predictor's serial `modelQueue` (training and prediction share it) bridged to `async` with `withCheckedThrowingContinuation`. Simulator-safe evaluation math lives in pure types (`ClassificationMetrics`, `RollingOriginPlan`, `WindowStatisticsCalculator`, `PersonalizationSelection`, `ProspectiveAccuracy`) so it can be unit-tested; `TrainingInput`/`Predictor` internals can only be exercised on device (Debug Settings ▸ Train Models).

### UI / design system

- **Design tokens** live in `Shared/Views/DesignSystem.swift` (`Tokens.Spacing`, `Tokens.Radius`, `Tokens.Motion`). Use them instead of inline magic numbers. Colors flow from the active `ColorTheme` (never hardcode system colors on themed surfaces — route through it, e.g. `colorTheme.color(for: confidence)`), so every built-in theme stays coherent. `DesignSystem.swift` documents the per-surface accent table.
- **`Card`** (`Shared/Views/Card.swift`) is the content atom: gradient-titled, self-drawing background, its own 15pt gutter. It renders in the widget *outside* a `List`, so never bake list behavior into it. When a card is a `List`/`Section` row, apply **`.cardListRow()`** (`Shared/Views/Modifiers/CardListRow.swift`) so it floats cleanly on the grouped background (zeroes the system inset, clears the cell background, hides the separator).
- **`Chip`** (`Shared/Views/Chip.swift`) is the one chip vocabulary (selected / unselected / readonly). Card-based screens use `SectionTitleView`/`SectionFooterView`; `Settings` stays a native `Form`. Depth is flat (no shadows/materials) — contrast only.
- **Visual verification**: the DEBUG-only `--uitest-seed` launch path (`Headache Tracker/Models/App/UITestSupport.swift`) seeds representative data and suppresses permission prompts; `Headache TrackerUITests/ScreenshotSweepTests.swift` drives every screen and captures screenshots. Run via the `sweep.sh`-style flow and inspect the exported PNGs. Never let this ship-affecting; it is all `#if DEBUG` / launch-arg gated.
